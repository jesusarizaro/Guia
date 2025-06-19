from flask import Flask
from flask_socketio import SocketIO, send
import eventlet

eventlet.monkey_patch()  # Permite el manejo asíncrono con Flask + Sock>
app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

@socketio.on('connect')
def handle_connect():
    print("📡 Cliente conectado")

@socketio.on('message')
def handle_message(msg):
    print(f"📥 Mensaje recibido: {msg}")
    send("Recibido")  # Esto es lo que tu app va a ver

if __name__ == '__main__':
    print("🚀 Servidor WebSocket corriendo en el puerto 5000")
    socketio.run(app, host='0.0.0.0', port=5000)
