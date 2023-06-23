from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from airflow.models.xcom import XCom

default_args = {"depends_on_past": True}

def myfunction(**context):
    print(int(context["ti"].xcom_pull(task_ids='tarea_2')) - 22)

with DAG(dag_id="9-XCom",
    description="Probando los XCom",
    schedule_interval="@daily",
    start_date=datetime(2023, 6, 22),
	default_args=default_args,
    max_active_runs=1
) as dag:

    t1 = BashOperator(task_id="tarea_1",
					  bash_command="sleep 5 && echo $((3 * 8))")

    t2 = BashOperator(task_id="tarea_2",
					  bash_command="sleep 3 && echo {{ ti.xcom_pull(task_ids='tarea_1') }}")

    t3 = PythonOperator(task_id="tarea_3", 
                        python_callable=myfunction)

    t1 >> t2 >> t3