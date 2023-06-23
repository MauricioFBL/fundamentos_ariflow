from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

def print_hello():
    print("holooooo0")


with DAG(
    dag_id='pythonoperator-dag',
    description='python operator example',
    start_date=datetime(2023,6,8),
    schedule_interval='@once') as dag:
    
    t1 = PythonOperator(
        task_id="python-dummy",
        python_callable=print_hello)
    t1