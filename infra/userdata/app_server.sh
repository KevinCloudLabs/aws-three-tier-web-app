#!/bin/bash
yum update -y
sudo dnf install -y python3-pip mariadb105
pip3 install flask pymysql boto3 flask-cors

mkdir -p /home/ec2-user/app

cat > /home/ec2-user/app/app.py << 'PYEOF'
from flask import Flask, request, jsonify
from flask_cors import CORS
import pymysql
import boto3
import os
import traceback

app = Flask(__name__)
CORS(app)

DB_HOST = os.environ.get('DB_HOST')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')
DB_NAME = os.environ.get('DB_NAME')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def get_db():
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor
    )

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy'})

@app.route('/cart', methods=['POST'])
def add_to_cart():
    data = request.json
    product_name = data.get('product_name')
    price = data.get('price')
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "INSERT INTO orders (product_name, price) VALUES (%s, %s)",
                (product_name, price)
            )
        conn.commit()
        sns = boto3.client('sns', region_name=os.environ.get('AWS_REGION', 'us-west-1'))
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject='Order Confirmation - KL Performance',
            Message=f'Your order for {product_name} (${price}) has been placed!'
        )
        return jsonify({'message': f'{product_name} added to cart!'}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
PYEOF

chown ec2-user:ec2-user /home/ec2-user/app/app.py