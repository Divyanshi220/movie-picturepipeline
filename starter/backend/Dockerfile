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

# Stable import path for uWSGI (do not import a module named __init__).
RUN printf '%s\n' \
  'import importlib.util' \
  'spec = importlib.util.spec_from_file_location("movie_backend", "/app/__init__.py")' \
  'module = importlib.util.module_from_spec(spec)' \
  'spec.loader.exec_module(module)' \
  'app = module.app' \
  > /app/wsgi.py

EXPOSE 5000

HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
  CMD curl -sf http://127.0.0.1:5000/movies || exit 1

CMD ["uwsgi", "--http", "0.0.0.0:5000", "--master", "--enable-threads", "--processes", "2", "--wsgi-file", "/app/wsgi.py", "--callable", "app", "--http-timeout", "60", "--die-on-term"]
