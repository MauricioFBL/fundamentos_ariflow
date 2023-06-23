from airflow import DAG
from airflow.operators.empty import EmptyOperator
from datetime import datetime


with DAG(
    dag_id= "Orquestracion3",
    description="Priuena de prquestracion 1",
    schedule_interval="* 7 * * 1", # lunes 7am * 7 * * 1
    start_date=datetime(2023, 6, 10),
    end_date=datetime(2023, 7, 10),
    # default_args={'depends_on_past':True}, # obliga a que la task anterior sea exitosa para continuar
    # max_active_runs=1 # corridas concurentes
    ) as dag:
    
    t1 = EmptyOperator(task_id="tarea_1")

    t2 = EmptyOperator(task_id="tarea_2")

    t3 = EmptyOperator(task_id="tarea_3")
    
    t4 = EmptyOperator(task_id="tarea_4")
    
    t1 >> t2 >> [t3, t4] 