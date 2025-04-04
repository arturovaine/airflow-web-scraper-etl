# Dockerized Airflow Web ETL

This project sets up a fully dockerized Apache Airflow pipeline to **scrape quotes from the web**, transform the data, and load it into a PostgreSQL database.  
Everything runs through Docker Compose, and the entire project can be bootstrapped with a single shell script.

---

## 📦 Quickstart

### 1. Make the shell script executable

```bash
chmod +x create_airflow_scraper_project.sh
```

### 2. Run the project setup

```bash
./create_airflow_scraper_project.sh
```

### 3. Activate the virtual environment

```bash
source venv/bin/activate
```

### 4. Build and start the containers

```bash
docker-compose up --build
```

Wait a few moments...

🌐 Access the Airflow UI

URL: http://localhost:8080

Username: admin
Password: admin

🏃 Run the DAG

Trigger the etl_web_scraper DAG from the Airflow UI.
It will scrape quote data, store it in PostgreSQL, and log each step.

🐘 Check the PostgreSQL Database
Enter the database container:

```bash
docker exec -it airflow-postgres psql -U airflow -d scraperdb
```

Run:

```sql
\\dt
\\c scraperdb
SELECT author, tags, created_at FROM quotes LIMIT 5;
```

✅ Output

Each quote includes:

- Quote text

- Author

- Tags

- Timestamp of extraction (created_at)

📁 Project Structure


```
airflow-webscraper/
├── dags/
│   └── etl_web_scraper.py
├── logs/
├── plugins/
├── docker-compose.yaml
├── requirements.txt
├── .gitignore
└── create_airflow_scraper_project.sh
```

📚 Tech Stack

- Python + Airflow

- Docker Compose

- PostgreSQL

- BeautifulSoup for web scraping

<!-- Feel free to customize or extend the pipeline — it's yours! -->

<!-- # Dockerized Airflow Web ETL

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

`\c scraperdb`

`SELECT author,tags,created_at FROM quotes LIMIT 5;` -->
