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
    && rm -rf /var/lib/apt/lists/* \
    && pip install pipenv

COPY Pipfile Pipfile.lock /app/

RUN pipenv install --system --deploy

COPY . /app

# Explicit WSGI module so uWSGI does not depend on importing __init__ by name.
RUN printf 'from __init__ import app\n' > /app/wsgi.py

EXPOSE 5000

CMD ["uwsgi", "--http", "0.0.0.0:5000", "--master", "--enable-threads", "--processes", "2", "--wsgi-file", "/app/wsgi.py", "--callable", "app", "--http-timeout", "60"]
