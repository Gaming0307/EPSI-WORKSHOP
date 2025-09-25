#!/usr/bin/env python3
# Messagerie D.I.P. - Mission Résistance
# Alternative sécurisée à Matrix pour intranet fermé
# Avec support messages privés, vocaux et partage de fichiers

from flask import Flask, render_template, request, jsonify, send_from_directory #type: ignore
from flask_socketio import SocketIO, emit, join_room, leave_room #type: ignore
import json
import datetime
import hashlib
import os
import uuid
import logging
import threading
import time
from werkzeug.utils import secure_filename  #type: ignore
from werkzeug.serving import WSGIRequestHandler #type: ignore

# Configuration logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration Flask
app = Flask(__name__)
app.config['SECRET_KEY'] = 'dip_mission_2024_secure_key'

# Configuration upload de fichiers
UPLOAD_FOLDER = 'uploads'
MAX_FILE_SIZE = 16 * 1024 * 1024  # 16MB
ALLOWED_EXTENSIONS = {
    'images': {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'},
    'audio': {'mp3', 'wav', 'ogg', 'webm', 'm4a', 'aac'},
    'documents': {'pdf', 'doc', 'docx', 'txt', 'xlsx', 'pptx', 'xls', 'ppt'},
    'archives': {'zip', 'rar', '7z', 'tar', 'gz'},
    'video': {'mp4', 'webm', 'avi', 'mov', 'mkv', 'flv'}
}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_FILE_SIZE

socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Création des dossiers d'upload
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(os.path.join(UPLOAD_FOLDER, 'audio'), exist_ok=True)
os.makedirs(os.path.join(UPLOAD_FOLDER, 'files'), exist_ok=True)

# Stockage en mémoire (pour simplicité intranet)
users = {}
rooms = {
    "general": {"messages": [], "users": set(), "topic": "Canal général - Mission D.I.P."},
    "ops": {"messages": [], "users": set(), "topic": "Opérations tactiques"},
    "tech": {"messages": [], "users": set(), "topic": "Support technique"},
    "intel": {"messages": [], "users": set(), "topic": "Renseignements"}
}
active_connections = {}
private_messages = {}  # Structure: {user_id: [messages]}
user_sessions = {}     # Structure: {username: session_id}

# Statistiques
stats = {
    "total_messages": 0,
    "total_connections": 0,
    "active_users": 0
}

# === UTILITAIRES FICHIERS ===

def allowed_file(filename):
    """Vérifier si le fichier est autorisé"""
    if '.' not in filename:
        return False
    
    ext = filename.rsplit('.', 1)[1].lower()
    for category in ALLOWED_EXTENSIONS.values():
        if ext in category:
            return True
    return False

def get_file_category(filename):
    """Déterminer la catégorie du fichier"""
    if '.' not in filename:
        return 'unknown'
    
    ext = filename.rsplit('.', 1)[1].lower()
    for category, extensions in ALLOWED_EXTENSIONS.items():
        if ext in extensions:
            return category
    return 'unknown'

# === ROUTES PRINCIPALES ===

@app.route('/')
def index():
    """Page d'accueil messagerie"""
    return render_template('chat.html')

@app.route('/api/rooms')
def get_rooms():
    """Liste des canaux disponibles"""
    room_list = []
    for name, data in rooms.items():
        room_list.append({
            'name': name,
            'topic': data.get('topic', ''),
            'user_count': len(data['users']),
            'message_count': len(data['messages'])
        })
    return jsonify(room_list)

@app.route('/api/messages/<room>')
def get_messages(room):
    """Historique des messages d'un canal"""
    if room in rooms:
        messages = rooms[room]["messages"][-100:]
        return jsonify(messages)
    return jsonify([])

@app.route('/api/stats')
def get_stats():
    """Statistiques du serveur"""
    stats["active_users"] = len(active_connections)
    return jsonify(stats)

@app.route('/health')
def health_check():
    """Vérification santé du serveur"""
    return jsonify({
        'status': 'operational',
        'uptime': 'active',
        'active_rooms': len(rooms),
        'active_users': len(active_connections),
        'total_messages': stats["total_messages"]
    })

# === ROUTES POUR LES FICHIERS ===

@app.route('/upload', methods=['POST'])
def upload_file():
    """Upload d'un fichier"""
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'Aucun fichier sélectionné'}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({'error': 'Nom de fichier vide'}), 400
        
        if not allowed_file(file.filename):
            return jsonify({'error': 'Type de fichier non autorisé'}), 400
        
        # Générer nom unique
        original_filename = secure_filename(file.filename)
        file_id = str(uuid.uuid4())
        file_extension = original_filename.rsplit('.', 1)[1].lower() if '.' in original_filename else ''
        unique_filename = f"{file_id}.{file_extension}" if file_extension else file_id
        
        # Déterminer le dossier selon le type
        file_category = get_file_category(original_filename)
        if file_category == 'audio':
            upload_path = os.path.join(UPLOAD_FOLDER, 'audio', unique_filename)
            file_url = f'/audio/{unique_filename}'
        else:
            upload_path = os.path.join(UPLOAD_FOLDER, 'files', unique_filename)
            file_url = f'/files/{unique_filename}'
        
        # Sauvegarder le fichier
        file.save(upload_path)
        
        # Calculer la taille
        file_size = os.path.getsize(upload_path)
        
        logger.info(f"Fichier uploadé: {original_filename} ({file_size} bytes)")
        
        return jsonify({
            'success': True,
            'file_id': file_id,
            'original_name': original_filename,
            'filename': unique_filename,
            'size': file_size,
            'category': file_category,
            'url': file_url
        })
    
    except Exception as e:
        logger.error(f"Erreur upload fichier: {e}")
        return jsonify({'error': 'Erreur lors de l\'upload'}), 500

@app.route('/files/<filename>')
def serve_file(filename):
    """Servir un fichier uploadé"""
    try:
        return send_from_directory(os.path.join(UPLOAD_FOLDER, 'files'), filename)
    except FileNotFoundError:
        return jsonify({'error': 'Fichier non trouvé'}), 404

@app.route('/audio/<filename>')
def serve_audio(filename):
    """Servir un fichier audio"""
    try:
        return send_from_directory(os.path.join(UPLOAD_FOLDER, 'audio'), filename)
    except FileNotFoundError:
        return jsonify({'error': 'Fichier audio non trouvé'}), 404

# === EVENTS WEBSOCKET PRINCIPAUX ===

@socketio.on('connect')
def on_connect():
    """Connexion d'un client"""
    stats["total_connections"] += 1
    logger.info(f"Nouvelle connexion: {request.sid}")
    
    # Envoyer les canaux disponibles
    emit('rooms_list', list(rooms.keys()))

@socketio.on('disconnect')
def on_disconnect(*args, **kwargs):
    """Déconnexion d'un client"""
    logger.info(f"Déconnexion: {request.sid}")
    
    # Retirer de toutes les rooms
    username = active_connections.get(request.sid, 'Agent Inconnu')
    
    for room_name in rooms:
        if request.sid in rooms[room_name]["users"]:
            rooms[room_name]["users"].discard(request.sid)
            
            # Notifier les autres utilisateurs
            emit('user_left', {
                'user': username,
                'room': room_name,
                'user_count': len(rooms[room_name]["users"]),
                'timestamp': datetime.datetime.now().strftime('%H:%M:%S')
            }, room=room_name)
    
    # Supprimer de la liste des sessions privées
    if username in user_sessions:
        del user_sessions[username]
    
    # Notifier les autres que l'utilisateur s'est déconnecté
    emit('user_offline', {'username': username}, broadcast=True)
    
    # Supprimer des connexions actives
    if request.sid in active_connections:
        del active_connections[request.sid]

@socketio.on('join')
def on_join(data):
    """Rejoindre un canal"""
    username = data['username']
    room = data['room']
    
    # Valider le nom d'utilisateur
    if not username or len(username) < 2:
        emit('error', {'message': 'Nom d\'agent invalide'})
        return
        
    if len(username) > 20:
        username = username[:20]
    
    # Créer le canal s'il n'existe pas
    if room not in rooms:
        rooms[room] = {"messages": [], "users": set(), "topic": f"Canal {room}"}
    
    # Rejoindre le canal
    join_room(room)
    rooms[room]["users"].add(request.sid)
    active_connections[request.sid] = username
    
    # Enregistrer la session utilisateur pour les messages privés
    user_sessions[username] = request.sid
    
    # Notifier les autres utilisateurs
    emit('user_joined', {
        'user': username,
        'room': room,
        'user_count': len(rooms[room]["users"]),
        'timestamp': datetime.datetime.now().strftime('%H:%M:%S')
    }, room=room)
    
    # Notifier qu'un nouvel utilisateur est en ligne (pour messages privés)
    emit('user_online', {'username': username}, broadcast=True, include_self=False)
    
    # Envoyer l'historique récent au nouvel utilisateur
    recent_messages = rooms[room]["messages"][-20:]
    emit('message_history', recent_messages)
    
    logger.info(f"Agent {username} a rejoint #{room}")

@socketio.on('leave')
def on_leave(data):
    """Quitter un canal"""
    username = data['username']
    room = data['room']
    
    leave_room(room)
    if room in rooms and request.sid in rooms[room]["users"]:
        rooms[room]["users"].discard(request.sid)
    
    # Notifier les autres
    emit('user_left', {
        'user': username,
        'room': room,
        'user_count': len(rooms[room]["users"]) if room in rooms else 0,
        'timestamp': datetime.datetime.now().strftime('%H:%M:%S')
    }, room=room)
    
    logger.info(f"Agent {username} a quitté #{room}")

@socketio.on('message')
def handle_message(data):
    """Recevoir et diffuser un message"""
    username = data['username']
    message = data['message'].strip()
    room = data['room']
    
    # Validation
    if not message or len(message) > 1000:
        emit('error', {'message': 'Message invalide'})
        return
        
    if room not in rooms:
        emit('error', {'message': 'Canal inexistant'})
        return
    
    # Créer le message
    msg = {
        'id': hashlib.md5(f"{username}{message}{datetime.datetime.now()}".encode()).hexdigest()[:8],
        'username': username,
        'message': message,
        'timestamp': datetime.datetime.now().strftime('%H:%M:%S'),
        'room': room,
        'date': datetime.datetime.now().strftime('%Y-%m-%d'),
        'type': 'text'
    }
    
    # Stocker le message
    rooms[room]["messages"].append(msg)
    stats["total_messages"] += 1
    
    # Limiter à 1000 messages par canal
    if len(rooms[room]["messages"]) > 1000:
        rooms[room]["messages"] = rooms[room]["messages"][-1000:]
    
    # Diffuser à tous les clients du canal
    emit('message', msg, room=room)
    
    logger.info(f"[#{room}] {username}: {message[:50]}...")

@socketio.on('typing')
def handle_typing(data):
    """Indicateur de frappe"""
    username = data['username']
    room = data['room']
    is_typing = data['is_typing']
    
    emit('typing', {
        'username': username,
        'is_typing': is_typing
    }, room=room, include_self=False)

@socketio.on('get_users')
def handle_get_users(data):
    """Liste des utilisateurs d'un canal"""
    room = data['room']
    if room in rooms:
        users_list = []
        for sid in rooms[room]["users"]:
            if sid in active_connections:
                users_list.append(active_connections[sid])
        
        emit('users_list', {
            'room': room,
            'users': users_list,
            'count': len(users_list)
        })

# === MESSAGES PRIVÉS ===

@socketio.on('send_private_message')
def handle_private_message(data):
    """Envoyer un message privé à un utilisateur spécifique"""
    sender = data['sender']
    recipient = data['recipient']
    message = data['message'].strip()
    
    if not message or len(message) > 1000:
        emit('error', {'message': 'Message privé invalide'})
        return
    
    # Vérifier que le destinataire existe et est connecté
    recipient_session = user_sessions.get(recipient)
    if not recipient_session:
        emit('error', {'message': f'Utilisateur {recipient} introuvable ou déconnecté'})
        return
    
    # Créer le message privé
    private_msg = {
        'id': hashlib.md5(f"{sender}{recipient}{message}{datetime.datetime.now()}".encode()).hexdigest()[:8],
        'sender': sender,
        'recipient': recipient,
        'message': message,
        'timestamp': datetime.datetime.now().strftime('%H:%M:%S'),
        'date': datetime.datetime.now().strftime('%Y-%m-%d'),
        'type': 'private'
    }
    
    # Stocker dans l'historique des deux utilisateurs
    for user in [sender, recipient]:
        if user not in private_messages:
            private_messages[user] = []
        private_messages[user].append(private_msg)
        
        # Limiter à 500 messages privés par utilisateur
        if len(private_messages[user]) > 500:
            private_messages[user] = private_messages[user][-500:]
    
    # Envoyer au destinataire
    emit('private_message', private_msg, room=recipient_session)
    
    # Confirmer à l'expéditeur
    emit('private_message', private_msg)
    
    logger.info(f"Message privé: {sender} -> {recipient}")

@socketio.on('get_private_messages')
def handle_get_private_messages(data):
    """Récupérer l'historique des messages privés avec un utilisateur"""
    requester = data['requester']
    other_user = data['other_user']
    
    if requester not in private_messages:
        emit('private_message_history', {'messages': [], 'with': other_user})
        return
    
    # Filtrer les messages entre ces deux utilisateurs
    conversation = []
    for msg in private_messages[requester]:
        if (msg['sender'] == requester and msg['recipient'] == other_user) or \
           (msg['sender'] == other_user and msg['recipient'] == requester):
            conversation.append(msg)
    
    # Trier par timestamp et limiter aux 100 derniers
    conversation = sorted(conversation, key=lambda x: x['timestamp'])[-100:]
    
    emit('private_message_history', {
        'messages': conversation,
        'with': other_user
    })

@socketio.on('get_online_users')
def handle_get_online_users():
    """Liste des utilisateurs connectés pour messages privés"""
    online_users = list(user_sessions.keys())
    emit('online_users_list', {'users': online_users})

@socketio.on('typing_private')
def handle_private_typing(data):
    """Indicateur de frappe pour messages privés"""
    sender = data['sender']
    recipient = data['recipient']
    is_typing = data['is_typing']
    
    recipient_session = user_sessions.get(recipient)
    if recipient_session:
        emit('private_typing', {
            'sender': sender,
            'is_typing': is_typing
        }, room=recipient_session)

# === MESSAGES AVEC FICHIERS ===

@socketio.on('send_file_message')
def handle_file_message(data):
    """Envoyer un message avec fichier attaché"""
    username = data['username']
    room = data['room']
    file_data = data['file_data']
    message_text = data.get('message', '').strip()
    
    if room not in rooms:
        emit('error', {'message': 'Canal inexistant'})
        return
    
    # Créer le message avec fichier
    msg = {
        'id': hashlib.md5(f"{username}{file_data['file_id']}{datetime.datetime.now()}".encode()).hexdigest()[:8],
        'username': username,
        'message': message_text,
        'timestamp': datetime.datetime.now().strftime('%H:%M:%S'),
        'room': room,
        'date': datetime.datetime.now().strftime('%Y-%m-%d'),
        'type': 'file',
        'file_data': {
            'file_id': file_data['file_id'],
            'original_name': file_data['original_name'],
            'filename': file_data['filename'],
            'size': file_data['size'],
            'category': file_data['category'],
            'url': file_data['url']
        }
    }
    
    # Stocker et diffuser
    rooms[room]["messages"].append(msg)
    stats["total_messages"] += 1
    
    # Limiter les messages
    if len(rooms[room]["messages"]) > 1000:
        rooms[room]["messages"] = rooms[room]["messages"][-1000:]
    
    emit('message', msg, room=room)
    logger.info(f"[#{room}] {username} a partagé: {file_data['original_name']}")

@socketio.on('send_audio_message')
def handle_audio_message(data):
    """Envoyer un message vocal"""
    username = data['username']
    room = data.get('room')
    recipient = data.get('recipient')  # Pour messages privés
    audio_data = data['audio_data']
    
    # Vérifier si c'est un message privé ou public
    if recipient:
        # Message vocal privé
        recipient_session = user_sessions.get(recipient)
        if not recipient_session:
            emit('error', {'message': f'Utilisateur {recipient} introuvable'})
            return
        
        private_msg = {
            'id': hashlib.md5(f"{username}{recipient}{audio_data['file_id']}{datetime.datetime.now()}".encode()).hexdigest()[:8],
            'sender': username,
            'recipient': recipient,
            'message': 'Message vocal',
            'timestamp': datetime.datetime.now().strftime('%H:%M:%S'),
            'date': datetime.datetime.now().strftime('%Y-%m-%d'),
            'type': 'audio',
            'audio_data': audio_data
        }
        
        # Stocker pour les deux utilisateurs
        for user in [username, recipient]:
            if user not in private_messages:
                private_messages[user] = []
            private_messages[user].append(private_msg)
            
            if len(private_messages[user]) > 500:
                private_messages[user] = private_messages[user][-500:]
        
        # Envoyer au destinataire et expéditeur
        emit('private_message', private_msg, room=recipient_session)
        emit('private_message', private_msg)
        
        logger.info(f"Message vocal privé: {username} -> {recipient}")
    
    else:
        # Message vocal public
        if room not in rooms:
            emit('error', {'message': 'Canal inexistant'})
            return
        
        msg = {
            'id': hashlib.md5(f"{username}{audio_data['file_id']}{datetime.datetime.now()}".encode()).hexdigest()[:8],
            'username': username,
            'message': 'Message vocal',
            'timestamp': datetime.datetime.now().strftime('%H:%M:%S'),
            'room': room,
            'date': datetime.datetime.now().strftime('%Y-%m-%d'),
            'type': 'audio',
            'audio_data': audio_data
        }
        
        rooms[room]["messages"].append(msg)
        stats["total_messages"] += 1
        
        if len(rooms[room]["messages"]) > 1000:
            rooms[room]["messages"] = rooms[room]["messages"][-1000:]
        
        emit('message', msg, room=room)
        logger.info(f"[#{room}] {username} a envoyé un message vocal")

@socketio.on('ping')
def handle_ping():
    """Ping/pong pour maintenir la connexion"""
    emit('pong')

# === GESTION ERREURS ===

@socketio.on_error_default
def default_error_handler(e):
    """Gestion des erreurs WebSocket"""
    logger.error(f"Erreur WebSocket: {e}")
    emit('error', {'message': 'Erreur de connexion'})

@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Page non trouvée'}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Erreur serveur: {error}")
    return jsonify({'error': 'Erreur serveur interne'}), 500

@app.errorhandler(413)
def request_entity_too_large(error):
    return jsonify({'error': 'Fichier trop volumineux (max 16MB)'}), 413

# === NETTOYAGE DES FICHIERS ===

def cleanup_old_files():
    """Nettoyer les anciens fichiers (plus de 7 jours)"""
    current_time = time.time()
    cleaned_count = 0
    
    for folder in ['files', 'audio']:
        folder_path = os.path.join(UPLOAD_FOLDER, folder)
        if os.path.exists(folder_path):
            for filename in os.listdir(folder_path):
                file_path = os.path.join(folder_path, filename)
                try:
                    # Supprimer les fichiers de plus de 7 jours
                    if current_time - os.path.getctime(file_path) > 7 * 24 * 3600:
                        os.remove(file_path)
                        cleaned_count += 1
                        logger.info(f"Fichier ancien supprimé: {filename}")
                except Exception as e:
                    logger.error(f"Erreur suppression {filename}: {e}")
    
    if cleaned_count > 0:
        logger.info(f"Nettoyage terminé: {cleaned_count} fichiers supprimés")

def periodic_cleanup():
    """Nettoyage périodique des fichiers"""
    while True:
        time.sleep(24 * 3600)  # Attendre 24h
        try:
            cleanup_old_files()
        except Exception as e:
            logger.error(f"Erreur nettoyage périodique: {e}")

# === DÉMARRAGE ===

if __name__ == '__main__':
    # Créer les dossiers nécessaires
    os.makedirs('templates', exist_ok=True)
    os.makedirs('static', exist_ok=True)
    
    # Démarrer le nettoyage en arrière-plan
    cleanup_thread = threading.Thread(target=periodic_cleanup, daemon=True)
    cleanup_thread.start()
    
    print("=" * 70)
    print("🛡️  MESSAGERIE D.I.P. - MISSION SÉCURISÉE")
    print("=" * 70)
    print("🔗 Interface: http://localhost:5000")
    print("🏠 Canaux: general, ops, tech, intel")
    print("💬 Messages privés: Activés")
    print("🎤 Messages vocaux: Activés")
    print("📎 Partage de fichiers: Activé (max 16MB)")
    print("👥 Multi-utilisateurs: Supporté")
    print("🗑️  Nettoyage auto: 7 jours")
    print("🚀 Serveur démarré - Résistance activée!")
    print("=" * 70)
    
    # Configuration serveur
    class QuietHandler(WSGIRequestHandler):
        def log_request(self, *args, **kwargs):
            pass
    
    # Démarrage serveur
    socketio.run(
        app, 
        host='0.0.0.0', 
        port=5000, 
        debug=True,
        use_reloader=False,
        request_handler=QuietHandler
    )