FROM public.ecr.aws/docker/library/python:3.10-slim

ENV FLASK_RUN_HOST=0.0.0.0
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    python3-dev \
    libpcre2-dev \
    libssl-dev \
    libffi-dev \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && pip install pipenv

COPY Pipfile Pipfile.lock /app/

RUN pipenv install --system --deploy

COPY . /app

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
  CMD curl -sf http://127.0.0.1:5000/movies || exit 1

# app.py imports the movies package with absolute imports (uWSGI-safe).
CMD ["uwsgi", "--http", "0.0.0.0:5000", "--master", "--enable-threads", "--processes", "2", "--wsgi-file", "/app/app.py", "--callable", "app", "--pythonpath", "/app", "--http-timeout", "60", "--die-on-term"]
