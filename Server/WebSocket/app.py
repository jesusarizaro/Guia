from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/upload-labels', methods=['POST'])
def upload_labels():
    labels = request.json  # Esperamos algo como ["person", "chair"]
    print("Received labels:", labels)
    return jsonify({"message": "Labels received"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
