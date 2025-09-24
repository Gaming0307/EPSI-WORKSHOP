"""
flask_forum.py

Version corrigée pour un mini-forum en un seul fichier, avec templates embarqués fonctionnant avec render_template_string.
"""
from flask import Flask, request, g, redirect, url_for, render_template_string, abort
import sqlite3
from datetime import datetime
import html

DATABASE = 'forum.db'
app = Flask(__name__)
app.config['SECRET_KEY'] = 'change-this-in-production'

# --- Templates embarquées ---
BASE_HTML = '''
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>{{ title or 'Mini-Forum' }}</title>
  <style>
    body { font-family: system-ui, -apple-system, 'Segoe UI', Roboto, 'Helvetica Neue', Arial; max-width:900px; margin:2rem auto; padding:0 1rem; color:#111 }
    header { margin-bottom:1.5rem }
    form { margin:1rem 0 }
    .thread { border:1px solid #ddd; padding:0.8rem; margin-bottom:0.8rem; border-radius:8px }
    .post { border-top:1px solid #eee; padding:0.6rem 0 }
    .meta { color:#666; font-size:0.9rem }
    input, textarea { width:100%; padding:0.5rem; margin-top:0.3rem; border-radius:6px; border:1px solid #ccc }
    button { padding:0.5rem 1rem; border-radius:6px; border:0; background:#0b63d0; color:white }
    a { color:#0b63d0; text-decoration:none }
  </style>
<body>
  <header>
    <h1><a href="{{ url_for('index') }}">Mini-Forum</a></h1>
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
        ) AS reply_count
        FROM threads t
        ORDER BY t.id DESC
    ''')
    threads = cur.fetchall()

    content = ''
    if threads:
        for t in threads:
            content += f"""
            <div class='thread'>
              <a href='{url_for('view_thread', thread_id=t['id'])}'><strong>{t['title']}</strong></a>
              <div class='meta'>par {t['author']} — {t['created_at']} — {t['reply_count']} réponse(s)</div>
            </div>
            """
    else:
        content += '<p>Aucun topic pour l\'instant. Créez-le ci-dessous !</p>'

    # Formulaire de création de topic
    content += f"""
    <h3>Créer un nouveau topic</h3>
    <form method='post' action='{url_for('create_thread')}'>
      <label>Titre<input name='title' required></label>
      <label>Auteur<input name='author' required placeholder='Votre pseudo'></label>
      <label>Message<textarea name='content' rows='5' required></textarea></label>
      <button type='submit'>Créer</button>
    </form>
    """

    return render_template_string(BASE_HTML, content=content)

@app.route('/create_thread', methods=['POST'])
def create_thread():
    title = request.form.get('title', '').strip()
    author = request.form.get('author', 'Anonyme').strip()
    content = request.form.get('content', '').strip()
    if not title or not content:
        abort(400, 'Titre et contenu requis')
    db = get_db()
    cur = db.cursor()
    created = now_iso()
    cur.execute('INSERT INTO threads (title, author, created_at) VALUES (?, ?, ?)', (title, author, created))
    thread_id = cur.lastrowid
    cur.execute('INSERT INTO posts (thread_id, author, content, created_at) VALUES (?, ?, ?, ?)',
                (thread_id, author, escape_and_format(content), created))
    db.commit()
    return redirect(url_for('view_thread', thread_id=thread_id))

@app.route('/thread/<int:thread_id>')
def view_thread(thread_id):
    db = get_db()
    cur = db.cursor()
    cur.execute('SELECT * FROM threads WHERE id = ?', (thread_id,))
    t = cur.fetchone()
    if not t:
        abort(404)
    cur.execute('SELECT * FROM posts WHERE thread_id = ? ORDER BY id ASC', (thread_id,))
    posts = cur.fetchall()

    content = f"""
    <a href='{url_for('index')}'>&larr; Retour</a>
    <h2>{t['title']}</h2>
    <div class='meta'>par {t['author']} — {t['created_at']}</div>
    <div style='margin-top:1rem; padding:0.6rem; background:#fafafa; border-radius:6px'>{posts[0]['content'] if posts else ''}</div>
    <h3 style='margin-top:1.2rem'>Réponses ({len(posts)})</h3>
    """

    for p in posts[1:]:
        content += f"""
        <div class='post'>
          <div class='meta'>{p['author']} — {p['created_at']}</div>
          <div style='margin-top:0.4rem'>{p['content']}</div>
        </div>
        """

    # Formulaire réponse
    content += f"""
    <h4>Répondre</h4>
    <form method='post' action='{url_for('reply', thread_id=thread_id)}'>
      <label>Auteur<input name='author' required placeholder='Votre pseudo'></label>
      <label>Message<textarea name='content' rows='4' required></textarea></label>
      <button type='submit'>Envoyer</button>
    </form>
    """

    return render_template_string(BASE_HTML, content=content)

@app.route('/thread/<int:thread_id>/reply', methods=['POST'])
def reply(thread_id):
    author = request.form.get('author', 'Anonyme').strip()
    content = request.form.get('content', '').strip()
    if not content:
        abort(400, 'Contenu requis')
    db = get_db()
    cur = db.cursor()
    cur.execute('SELECT id FROM threads WHERE id = ?', (thread_id,))
    if not cur.fetchone():
        abort(404)
    created = now_iso()
    cur.execute('INSERT INTO posts (thread_id, author, content, created_at) VALUES (?, ?, ?, ?)',
                (thread_id, author, escape_and_format(content), created))
    db.commit()
    return redirect(url_for('view_thread', thread_id=thread_id))

if __name__ == '__main__':
    with app.app_context():
        init_db()
    print('Démarrage du mini-forum sur http://127.0.0.1:5000')
    app.run(host='0.0.0.0',port=5000,debug=True)
