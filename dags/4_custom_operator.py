from airflow import DAG
from datetime import datetime
from hellooperator import HelloOperator

with DAG(
    dag_id='custom_operator',
    description='crear un customer operator',
    start_date=datetime(2023,6,8),
    schedule_interval='@once') as dag:
    
    t1 = HelloOperator(
        task_id="hello",
        name="mau"
    )
    t1