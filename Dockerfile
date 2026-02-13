FROM python:3.9-slim

LABEL maintainer="SAE DevOps"

# Créer le répertoire de travail
WORKDIR /app

# Copier les fichiers de dépendances
COPY requirements.txt .

# Installer les dépendances
RUN pip install --no-cache-dir -r requirements.txt

# Copier tout le code source
COPY addrservice/ ./addrservice/
COPY configs/ ./configs/
COPY data/ ./data/
COPY schema/ ./schema/

# Exposer le port 8080
EXPOSE 8080

# Commande pour lancer l'application
CMD ["python3", "addrservice/tornado/server.py", "--port", "8080", "--config", "./configs/addressbook-local.yaml"]
