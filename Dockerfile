ARG PORT
ARG DB_HOST
ARG DB_NAME
ARG DB_USERNAME
ARG DB_PASSWORD
ARG SERVER_HOST
ARG SERVER_PORT
ARG MAIN_SCHEMA=gns
ARG RESET=false

FROM python:3.10

ENV PYTHONUNBUFFERED True

# Copy local code to the container image.
ENV APP_HOME /app
WORKDIR $APP_HOME
COPY . ./

# Install production dependencies.
RUN pip install --no-cache-dir -e .

CMD python3 hive_gns/run_hive_gns.py