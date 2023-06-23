from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG(
    dag_id='bashoperator-dag',
    description='bash operator example',
    start_date=datetime(2023,6,8),
    schedule_interval='@once') as dag:
    t1 = BashOperator(
        task_id="bash-dummy",
        bash_command='echo "Hola amigos de youtube"')
    t1