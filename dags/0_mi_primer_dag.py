from airflow import DAG
from airflow.operators.empty import EmptyOperator
from datetime import datetime

with DAG(
    dag_id='primer-dag',
    description='Primer dag ejemplo',
    start_date=datetime(2023,6,10),
    schedule_interval='@once'
) as dafg:
    t1 = EmptyOperator(task_id="dummy")
    t1