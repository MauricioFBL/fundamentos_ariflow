from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from datetime import datetime

def print_hello():
    print("holooooo")


with DAG(
    dag_id='dependencias-dag',
    description='crear dependencias entre tareas',
    start_date=datetime(2023,6,8),
    schedule_interval='@once') as dag:
    
    t1 = PythonOperator(
        task_id="python-dummy",
        python_callable=print_hello)

    t2 = BashOperator(
        task_id="task1",
        bash_command='echo "Hola amigos de youtube 1"')
    
    t3 = BashOperator(
        task_id="task2",
        bash_command='echo "Hola amigos de youtube 2"')
    
    t4 = BashOperator(
        task_id="task3",
        bash_command='echo "Hola amigos de youtube 3"')
    
    t5 = BashOperator(
        task_id="task4",
        bash_command='echo "Hola amigos de youtube 3"')
    
    # t1.set_downstream(t2)
    # t2.set_downstream([t3,t4])

    t1 >> t2 >> [t3,t4]
    t3 >> t5