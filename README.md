# Airflow Web Scraper ETL

1. Make the shell script executable

    `chmod +x create_airflow_scraper_project.sh`

2. Run the project

    `./create_airflow_scraper_project.sh`

3. Activate the virtual environment

    `source venv/bin/activate`

4. Build the docker

    `docker-compose up --build`

Wait the processing...

5. Access the Airflow

    `localhost:8080`

User:password

    `admin:admin`

6. Run the DAG

Wait the processing...

7. Check the database

`docker exec -it airflow-postgres psql -U airflow -d scraperdb`

`\dt`

`SELECT * FROM posts LIMIT 5;`
