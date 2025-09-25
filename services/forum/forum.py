"""
flask_forum.py

Forum D.I.P. - Style cohérent avec la messagerie
"""
from flask import Flask, request, g, redirect, url_for, render_template_string, abort #type: ignore
import sqlite3
from datetime import datetime
import html

DATABASE = 'forum.db'
app = Flask(__name__)
app.config['SECRET_KEY'] = 'dip_mission_forum_2024_secure'

# --- Templates embarquées avec style D.I.P. ---
BASE_HTML = '''
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>{{ title or 'Forum D.I.P. - Mission Sécurisée' }}</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #0c1419 0%, #1a252f 50%, #2c3e50 100%);
      min-height: 100vh;
      color: #ecf0f1;
      line-height: 1.6;
    }

    header {
      background: rgba(0, 0, 0, 0.4);
      border-bottom: 2px solid #34495e;
      padding: 20px 0;
      text-align: center;
      margin-bottom: 30px;
      backdrop-filter: blur(10px);
    }

    header h1 {
      color: #3498db;
      font-size: 2em;
      margin-bottom: 5px;
    }

    header h1 a {
      color: #3498db;
      text-decoration: none;
      transition: color 0.3s ease;
    }

    header h1 a:hover {
      color: #5dade2;
    }

    .subtitle {
      color: #bdc3c7;
      font-size: 0.9em;
      text-transform: uppercase;
      letter-spacing: 1px;
    }

    main {
      max-width: 800px;
      margin: 0 auto;
      padding: 0 20px;
    }

    .thread, .post, .form-container {
      background: rgba(52, 73, 94, 0.3);
      border: 1px solid #34495e;
      border-left: 4px solid #3498db;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 20px;
      backdrop-filter: blur(10px);
      box-shadow: 0 5px 15px rgba(0, 0, 0, 0.2);
      transition: all 0.3s ease;
      animation: slideIn 0.3s ease;
    }

    @keyframes slideIn {
      from { opacity: 0; transform: translateY(20px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .thread:hover, .post:hover {
      transform: translateY(-2px);
      box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
      background: rgba(52, 73, 94, 0.4);
    }

    .thread h2, .thread a {
      color: #3498db;
      text-decoration: none;
      font-weight: bold;
      font-size: 1.3em;
      transition: color 0.3s ease;
    }

    .thread a:hover {
      color: #5dade2;
    }

    .meta {
      font-size: 0.9em;
      color: #95a5a6;
      margin-top: 10px;
      padding-top: 10px;
      border-top: 1px solid rgba(149, 165, 166, 0.2);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .author {
      color: #e67e22;
      font-weight: bold;
    }

    .date {
      color: #95a5a6;
    }

    .reply-count {
      background: rgba(52, 152, 219, 0.3);
      color: #3498db;
      padding: 4px 8px;
      border-radius: 12px;
      font-size: 0.8em;
      font-weight: bold;
    }

    h2, h3, h4 {
      color: #3498db;
      margin-bottom: 15px;
    }

    h3 {
      border-bottom: 2px solid #34495e;
      padding-bottom: 10px;
    }

    .back-link {
      display: inline-block;
      background: rgba(52, 73, 94, 0.5);
      color: #3498db;
      padding: 10px 15px;
      border-radius: 5px;
      text-decoration: none;
      margin-bottom: 20px;
      transition: all 0.3s ease;
    }

    .back-link:hover {
      background: rgba(52, 152, 219, 0.3);
      transform: translateX(-5px);
    }

    .thread-content {
      background: rgba(0, 0, 0, 0.2);
      padding: 15px;
      border-radius: 8px;
      border-left: 3px solid #2ecc71;
      margin: 15px 0;
    }

    form {
      display: flex;
      flex-direction: column;
      gap: 15px;
    }

    label {
      display: flex;
      flex-direction: column;
      font-weight: bold;
      color: #bdc3c7;
      font-size: 0.9em;
    }

    input, textarea {
      padding: 12px;
      border: 2px solid #34495e;
      border-radius: 8px;
      background: rgba(0, 0, 0, 0.3);
      color: white;
      font-size: 16px;
      transition: border-color 0.3s ease;
      margin-top: 5px;
    }

    input:focus, textarea:focus {
      outline: none;
      border-color: #3498db;
      background: rgba(0, 0, 0, 0.4);
    }

    input::placeholder, textarea::placeholder {
      color: #7f8c8d;
    }

    button {
      background: linear-gradient(135deg, #3498db, #2980b9);
      color: white;
      border: none;
      padding: 12px 25px;
      border-radius: 8px;
      cursor: pointer;
      font-size: 16px;
      font-weight: bold;
      transition: all 0.3s ease;
      align-self: flex-start;
    }

    button:hover {
      background: linear-gradient(135deg, #5dade2, #3498db);
      transform: translateY(-2px);
      box-shadow: 0 5px 15px rgba(52, 152, 219, 0.4);
    }

    .no-topics {
      text-align: center;
      color: #95a5a6;
      font-style: italic;
      padding: 40px 20px;
      background: rgba(149, 165, 166, 0.1);
      border-radius: 8px;
      border: 1px dashed #95a5a6;
    }

    .post {
      border-left-color: #e67e22;
      margin-left: 20px;
    }

    .post .author {
      color: #f39c12;
    }

    .post-content {
      margin-top: 10px;
      line-height: 1.7;
    }

    .form-container {
      border-left-color: #2ecc71;
    }

    .form-container h3, .form-container h4 {
      color: #2ecc71;
    }

    .stats {
      display: flex;
      gap: 20px;
      margin-bottom: 30px;
    }

    .stat-item {
      background: rgba(52, 152, 219, 0.2);
      padding: 15px;
      border-radius: 8px;
      text-align: center;
      flex: 1;
    }

    .stat-number {
      font-size: 2em;
      font-weight: bold;
      color: #3498db;
    }

    .stat-label {
      color: #95a5a6;
      font-size: 0.9em;
      text-transform: uppercase;
      letter-spacing: 1px;
    }

    .error-message {
      background: rgba(231, 76, 60, 0.3);
      border: 1px solid #e74c3c;
      color: #e74c3c;
      padding: 15px;
      border-radius: 8px;
      margin-bottom: 20px;
      text-align: center;
    }

    @media (max-width: 768px) {
      main {
        padding: 0 15px;
      }
      
      .thread, .post, .form-container {
        padding: 15px;
        margin-left: 0;
      }
      
      .post {
        margin-left: 10px;
      }
      
      .stats {
        flex-direction: column;
        gap: 10px;
      }
    }
  </style>
</head>
<body>
  <header>
    <h1><a href="{{ url_for('index') }}">🛡️ Forum D.I.P.</a></h1>
    <div class="subtitle">Mission Sécurisée - Réseau Fermé</div>
  </header>
  <main>
    {{ content|safe }}
  </main>
</body>
</html>
'''

# --- Database helpers ---

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def init_db():
    db = get_db()
    cur = db.cursor()
    cur.execute('''
        CREATE TABLE IF NOT EXISTS threads (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
    ''')
    cur.execute('''
        CREATE TABLE IF NOT EXISTS posts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            thread_id INTEGER NOT NULL,
            author TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY(thread_id) REFERENCES threads(id) ON DELETE CASCADE
        )
    ''')
    db.commit()

# --- Utilities ---

def now_iso():
    return datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')

def escape_and_format(text):
    return html.escape(text).replace('\n', '<br>')

def get_forum_stats():
    """Obtenir les statistiques du forum"""
    db = get_db()
    cur = db.cursor()
    
    # Nombre total de threads
    cur.execute('SELECT COUNT(*) as count FROM threads')
    thread_count = cur.fetchone()['count']
    
    # Nombre total de posts
    cur.execute('SELECT COUNT(*) as count FROM posts')
    post_count = cur.fetchone()['count']
    
    # Nombre d'utilisateurs uniques
    cur.execute('SELECT COUNT(DISTINCT author) as count FROM threads UNION SELECT COUNT(DISTINCT author) FROM posts')
    users = cur.fetchall()
    user_count = len(set([row['count'] for row in users]))
    
    return {
        'threads': thread_count,
        'posts': post_count,
        'users': user_count
    }

# --- Routes ---

@app.route('/')
def index():
    with app.app_context():
        init_db()
    
    db = get_db()
    cur = db.cursor()
    cur.execute('''
        SELECT t.*, (
            SELECT COUNT(*) FROM posts p WHERE p.thread_id = t.id
        ) AS reply_count,
        (
            SELECT p.created_at FROM posts p WHERE p.thread_id = t.id ORDER BY p.id DESC LIMIT 1
        ) AS last_reply
        FROM threads t
        ORDER BY COALESCE(last_reply, t.created_at) DESC
    ''')
    threads = cur.fetchall()
    
    # Statistiques
    stats = get_forum_stats()
    
    content = f'''
    <div class="stats">
        <div class="stat-item">
            <div class="stat-number">{stats['threads']}</div>
            <div class="stat-label">Topics</div>
        </div>
        <div class="stat-item">
            <div class="stat-number">{stats['posts']}</div>
            <div class="stat-label">Messages</div>
        </div>
        <div class="stat-item">
            <div class="stat-number">{stats['users']}</div>
            <div class="stat-label">Agents</div>
        </div>
    </div>
    '''
    
    if threads:
        for t in threads:
            last_activity = t['last_reply'] or t['created_at']
            content += f"""
            <div class='thread'>
              <a href='{url_for('view_thread', thread_id=t['id'])}'>{html.escape(t['title'])}</a>
              <div class='meta'>
                <div>
                    <span class='author'>{html.escape(t['author'])}</span>
                    <span class='date'> • {t['created_at']}</span>
                </div>
                <span class='reply-count'>{t['reply_count']} réponse(s)</span>
              </div>
            </div>
            """
    else:
        content += '''
        <div class='no-topics'>
            <h3>🚀 Aucun topic pour l'instant</h3>
            <p>Soyez le premier agent à lancer une discussion sécurisée !</p>
        </div>
        '''

    # Formulaire de création de topic
    content += f"""
    <div class='form-container'>
        <h3>🆕 Créer un nouveau topic</h3>
        <form method='post' action='{url_for('create_thread')}'>
          <label>
            Titre du topic
            <input name='title' required placeholder='Sujet de discussion...'>
          </label>
          <label>
            Agent responsable
            <input name='author' required placeholder='Votre nom d\'agent'>
          </label>
          <label>
            Message initial
            <textarea name='content' rows='6' required placeholder='Décrivez le sujet de discussion...'></textarea>
          </label>
          <button type='submit'>🚀 Créer le topic</button>
        </form>
    </div>
    """

    return render_template_string(BASE_HTML, content=content)

@app.route('/create_thread', methods=['POST'])
def create_thread():
    title = request.form.get('title', '').strip()
    author = request.form.get('author', 'Agent Anonyme').strip()
    content = request.form.get('content', '').strip()
    
    if not title or not content:
        error_content = '''
        <div class="error-message">
            ❌ Erreur: Titre et contenu requis pour créer un topic
        </div>
        <a href="{}" class="back-link">← Retour au forum</a>
        '''.format(url_for('index'))
        return render_template_string(BASE_HTML, content=error_content), 400
    
    db = get_db()
    cur = db.cursor()
    created = now_iso()
    
    try:
        cur.execute('INSERT INTO threads (title, author, created_at) VALUES (?, ?, ?)', 
                   (title, author, created))
        thread_id = cur.lastrowid
        cur.execute('INSERT INTO posts (thread_id, author, content, created_at) VALUES (?, ?, ?, ?)',
                   (thread_id, author, escape_and_format(content), created))
        db.commit()
        return redirect(url_for('view_thread', thread_id=thread_id))
    except Exception as e:
        error_content = f'''
        <div class="error-message">
            ❌ Erreur lors de la création du topic: {str(e)}
        </div>
        <a href="{url_for('index')}" class="back-link">← Retour au forum</a>
        '''
        return render_template_string(BASE_HTML, content=error_content), 500

@app.route('/thread/<int:thread_id>')
def view_thread(thread_id):
    db = get_db()
    cur = db.cursor()
    cur.execute('SELECT * FROM threads WHERE id = ?', (thread_id,))
    t = cur.fetchone()
    
    if not t:
        error_content = '''
        <div class="error-message">
            ❌ Topic non trouvé
        </div>
        <a href="{}" class="back-link">← Retour au forum</a>
        '''.format(url_for('index'))
        return render_template_string(BASE_HTML, content=error_content), 404
    
    cur.execute('SELECT * FROM posts WHERE thread_id = ? ORDER BY id ASC', (thread_id,))
    posts = cur.fetchall()

    content = f"""
    <a href='{url_for('index')}' class='back-link'>← Retour au forum</a>
    
    <div class='thread'>
        <h2>{html.escape(t['title'])}</h2>
        <div class='meta'>
            <div>
                <span class='author'>{html.escape(t['author'])}</span>
                <span class='date'> • {t['created_at']}</span>
            </div>
        </div>
    </div>
    """
    
    if posts:
        # Premier post (message initial)
        first_post = posts[0]
        content += f"""
        <div class='thread-content'>
            {first_post['content']}
        </div>
        """
        
        # Réponses
        if len(posts) > 1:
            content += f"<h3>💬 Réponses ({len(posts) - 1})</h3>"
            for p in posts[1:]:
                content += f"""
                <div class='post'>
                  <div class='meta'>
                    <div>
                        <span class='author'>{html.escape(p['author'])}</span>
                        <span class='date'> • {p['created_at']}</span>
                    </div>
                  </div>
                  <div class='post-content'>{p['content']}</div>
                </div>
                """
        else:
            content += "<p style='text-align: center; color: #95a5a6; margin: 30px 0;'>Aucune réponse pour l'instant. Soyez le premier à répondre !</p>"

    # Formulaire réponse
    content += f"""
    <div class='form-container'>
        <h4>✍️ Répondre à ce topic</h4>
        <form method='post' action='{url_for('reply', thread_id=thread_id)}'>
          <label>
            Agent
            <input name='author' required placeholder='Votre nom d\'agent'>
          </label>
          <label>
            Votre réponse
            <textarea name='content' rows='5' required placeholder='Votre message...'></textarea>
          </label>
          <button type='submit'>📤 Envoyer la réponse</button>
        </form>
    </div>
    """

    return render_template_string(BASE_HTML, content=content)

@app.route('/thread/<int:thread_id>/reply', methods=['POST'])
def reply(thread_id):
    author = request.form.get('author', 'Agent Anonyme').strip()
    content = request.form.get('content', '').strip()
    
    if not content:
        error_content = '''
        <div class="error-message">
            ❌ Erreur: Le contenu de la réponse est requis
        </div>
        <a href="{}" class="back-link">← Retour au topic</a>
        '''.format(url_for('view_thread', thread_id=thread_id))
        return render_template_string(BASE_HTML, content=error_content), 400
    
    db = get_db()
    cur = db.cursor()
    cur.execute('SELECT id FROM threads WHERE id = ?', (thread_id,))
    
    if not cur.fetchone():
        error_content = '''
        <div class="error-message">
            ❌ Topic non trouvé
        </div>
        <a href="{}" class="back-link">← Retour au forum</a>
        '''.format(url_for('index'))
        return render_template_string(BASE_HTML, content=error_content), 404
    
    created = now_iso()
    try:
        cur.execute('INSERT INTO posts (thread_id, author, content, created_at) VALUES (?, ?, ?, ?)',
                   (thread_id, author, escape_and_format(content), created))
        db.commit()
        return redirect(url_for('view_thread', thread_id=thread_id))
    except Exception as e:
        error_content = f'''
        <div class="error-message">
            ❌ Erreur lors de l'ajout de la réponse: {str(e)}
        </div>
        <a href="{url_for('view_thread', thread_id=thread_id)}" class="back-link">← Retour au topic</a>
        '''
        return render_template_string(BASE_HTML, content=error_content), 500

if __name__ == '__main__':
    with app.app_context():
        init_db()
    print('=' * 60)
    print('🛡️  FORUM D.I.P. - MISSION SÉCURISÉE')
    print('=' * 60)
    print('🔗 Interface: http://127.0.0.1:5000')
    print('💬 Forum de discussion sécurisé')
    print('👥 Multi-agents supporté')
    print('🚀 Serveur démarré - Forum opérationnel!')
    print('=' * 60)
    app.run(host='0.0.0.0', port=5001, debug=True)
