from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime


with DAG(
    dag_id= "Orquestracion1",
    description="Priuena de prquestracion 1",
    schedule_interval="@daily",
    start_date=datetime(2023, 6, 10),
    end_date=datetime(2023, 7, 10),
    default_args={'depends_on_past':True}, # obliga a que la task anterior sea exitosa para continuar
    max_active_runs=1 # corridas concurentes
    ) as dag:
    
    t1 = BashOperator(
        task_id="tarea1",
        bash_command="sleep 2 && echo 'Tarea 1'")

    t2 = BashOperator(
        task_id="tarea2",
        bash_command="sleep 2 && echo 'Tarea 2'")

    t3 = BashOperator(
        task_id="tarea3",
        bash_command="sleep 2 && echo 'Tarea 3'")
    
    t4 = BashOperator(
        task_id="tarea4",
        bash_command="sleep 2 && echo 'Tarea 4'")
    
    t1 >> t2 >> [t3, t4] 