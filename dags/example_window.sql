WITH base AS (
  SELECT
   b.broker_id,
    LOWER(TRIM(b.b_mail)) AS b_mail,
    LOWER(TRIM(b.b_commercial)) AS correo_comercial,
  FROM `papyrus-data.habi_wh_bi.tabla_madre_brokers`b
  LEFT JOIN `papyrus-data.habi_wh_bi.tabla_equipos_hunters_farmers`hf ON LOWER(hf.broker) = LOWER(b.b_mail) 
  QUALIFY ROW_NUMBER() OVER (PARTITION BY b.broker_id ORDER BY b.date DESC) = 1 
),
conteos AS (
  SELECT
    lower(l.b_mail) as broker,
    b.correo_comercial,
    CAST(l.date AS DATE)  date,
    countif(type='Logueo') as logueos,
    countif(type='visita agendada') as visitas,
    countif(type ='oferta') as ofertas,
  FROM `papyrus-data.habi_wh_bi.tabla_madre_brokers`l
  LEFT JOIN base b ON b.broker_id = l.broker_id 
  WHERE DATE_DIFF(CURRENT_DATE(), date, MONTH) <= 2
  AND l.b_mail IS NOT NULL
  GROUP BY 1, 2, 3
),
clientes AS (
  SELECT
    lower(b_mail) AS broker,
    b.correo_comercial,
    CAST(created_at AS DATE) date, 
    COUNT(DISTINCT(nid)) AS clientes
  FROM `papyrus-data.habi_wh_brokers.lead` AS l
  LEFT JOIN base b ON b.broker_id = l.broker_id 
  WHERE DATE_DIFF(CURRENT_DATE(), DATE(created_at), MONTH) <= 2
  GROUP BY 1,2,3
),
cierres_buyer as(
  SELECT
   lower(c_broker) AS broker,
   c_comercial AS comercial,
   CAST(c_fecha_promesa as date)  date,
   count(*) cierres_ibuyer
  FROM `papyrus-data.habi_wh_bi.consolidado_cierres_buyers_col` AS c
  WHERE dummie_des_c_fecha_carta_intencion = 0
  AND DATE_DIFF(CURRENT_DATE(), DATE(c_fecha_carta_intencion), MONTH) <= 2
  GROUP BY 1,2, 3
),

cierres_inmo AS (
  SELECT
  lower(correo_broker) AS broker,
  comercial AS comercial,
  CAST(fecha_promesa_compra_venta AS DATE) date,
  count(*) cierres_inmo
  
  FROM `papyrus-data.habi_wh_bi.consolidado_cierres_inmobiliaria_col`c
  WHERE DATE_DIFF(CURRENT_DATE(), DATE(IFNULL(fecha_carta_de_intencion, fecha_promesa_compra_venta)), MONTH) <= 2 
  AND correo_broker is not null
  AND fecha_promesa_compra_venta IS NOT NULL
  GROUP BY 1,2, 3
),
a AS (

  SELECT c.broker, 
  c.correo_comercial AS comercial, 
  c.date,
  IFNULL(logueos, 0) AS logueos, 
  IFNULL(clientes, 0) AS clientes,
  IFNULL(visitas, 0) AS visitas,
  IFNULL(ofertas,0) AS ofertas,
  IFNULL(cierres_ibuyer,0) + IFNULL(cierres_inmo,0) AS cierres, 
  IFNULL (cierres_ibuyer,0) as cierres_buyer,
  IFNULL (cierres_inmo,0) as cieres_inmo,

  FROM conteos c
  LEFT JOIN clientes cl ON cl.broker = c.broker AND cl.date = c.date
  LEFT JOIN cierres_buyer b ON b.broker = c.broker AND b.date = c.date
  LEFT JOIN cierres_inmo i ON i.broker = c.broker AND i.date = c.date
),
avg_logeos AS (

  SELECT
    a.comercial,
    a.date,
    AVG(a.logueos) AS promedio_logs,
    AVG(a.cierres) AS promedio_cierres_comercial,

    FROM a
    GROUP BY 1,2
),
cvrs_broker AS (

  SELECT
    a.broker,
    a.date,
    IFNULL(SAFE_DIVIDE(SUM(a.clientes), SUM(a.visitas)), 0) AS cvr_clientes_visitas_broker,
    IFNULL(SAFE_DIVIDE(SUM(a.ofertas), SUM(a.visitas)), 0) AS cvr_ofertas_visitas_broker,
    IFNULL(SAFE_DIVIDE(SUM(a.cierres), SUM(a.ofertas)), 0) AS cvr_cierres_ofertas_broker
    FROM a
    GROUP BY 1,2
)

, cvrs_comercial AS (

  SELECT
    a.comercial,
    a.date,
    IFNULL(SAFE_DIVIDE(SUM(a.clientes), SUM(a.visitas)), 0) AS cvr_visitas_clientes_comercial,
    IFNULL(SAFE_DIVIDE(SUM(a.ofertas), SUM(a.visitas)), 0) AS cvr_ofertas_visitas_comercial,
    IFNULL(SAFE_DIVIDE(SUM(a.cierres), SUM(a.ofertas)), 0) AS cvr_cierres_ofertas_comercial
    FROM a
    GROUP BY 1,2
)
, w AS (
  SELECT
    a.*,
    c.* EXCEPT(broker, date),
    co.* EXCEPT(comercial, date),
    v.promedio_logs,
    v.promedio_cierres_comercial,
    v.promedio_logs * 0.15 AS P_promedio_logs,
    co.cvr_visitas_clientes_comercial * 0.10 AS P_cvr_visitas_clientes_comercial,
    co.cvr_ofertas_visitas_comercial * 0.10 AS P_cvr_ofertas_visitas_comercial,
    co.cvr_cierres_ofertas_comercial * 0.65 AS P_cvr_cierres_ofertas_comercial
    FROM a
    LEFT JOIN avg_logeos AS v ON v.comercial = a.comercial AND v.date = a.date
    LEFT JOIN cvrs_broker AS c ON a.broker = c.broker AND c.date = a.date
    LEFT JOIN cvrs_comercial AS co ON a.comercial = co.comercial AND co.date = a.date

    ORDER BY 1 DESC
), 
puntaje_broker AS (
  SELECT
    w.*,
      IFNULL((SAFE_DIVIDE(w.cvr_clientes_visitas_broker, w.P_cvr_visitas_clientes_comercial) ), 0)
      + IFNULL((SAFE_DIVIDE(w.cvr_ofertas_visitas_broker, w.P_cvr_ofertas_visitas_comercial) ), 0)
      + IFNULL((SAFE_DIVIDE(w.cvr_cierres_ofertas_broker, w.P_cvr_cierres_ofertas_comercial) ), 0)
    AS puntaje_individual,
    FROM w
), 
puntaje_comercial AS (
  SELECT
    p.comercial,
    MAX(puntaje_individual) AS puntaje_grupal,

    FROM puntaje_broker AS p
    GROUP BY 1
),
QUERY_RETOOL_DATE AS (
SELECT
  b.broker_id,
  pb.*,
  pc.* EXCEPT(comercial),

  CASE
    WHEN cierres < promedio_cierres_comercial * 0.25 THEN 'Amateur'
    WHEN cierres BETWEEN promedio_cierres_comercial * 0.25 AND promedio_cierres_comercial * 0.50 THEN 'Avanzado'
    WHEN cierres BETWEEN promedio_cierres_comercial * 0.50 AND promedio_cierres_comercial * 0.75 THEN 'Master'
    WHEN cierres > promedio_cierres_comercial * 0.75 THEN 'Senior'
  END AS categoria,
  # que esté debajo del 40 % del promedio
  CASE
    WHEN logueos < (promedio_logs * 0.4) THEN 'No ingresa al portal'
    WHEN cvr_clientes_visitas_broker < (cvr_visitas_clientes_comercial * 0.4) THEN 'Pocos clientes - Problema de Leads'
    WHEN cvr_ofertas_visitas_broker < (cvr_ofertas_visitas_comercial * 0.4) THEN 'Visita pero no oferta - Problema de perfilamiento'
    WHEN cvr_cierres_ofertas_broker < (cvr_cierres_ofertas_comercial * 0.4) THEN 'Oferta pero no cierra - Problema de cierre' 
    ELSE 'Va bien - Motivalo !!'
  END AS tipo_error
  FROM puntaje_broker AS pb
  LEFT JOIN puntaje_comercial AS pc ON pb.comercial = pc.comercial
  left join base as b on b.b_mail = pb.broker


  -- WHERE pb.comercial = 'vivianachacon@habi.co'

  ORDER BY categoria DESC),
gestion as(
SELECT broker_id, date(fecha_seguimiento) fecha_seguimiento, count(tipo_gestion) count_s
FROM `papyrus-data.habi_wh_analytics.gestion_brokers_v2` gb 
WHERE fecha_seguimiento is not null
group by 1,2),
--_______--

brokers_por_gestionar AS(
  SELECT t.*, 
        sum(count_s) over (
            PARTITION BY broker_id 
            --ORDER BY date desc rows between 1  PRECEDING AND CURRENT ROW) gestion_s
            ORDER BY UNIX_DATE(fecha_seguimiento) RANGE BETWEEN 1 PRECEDING AND 1 FOLLOWING) gestion_s
        FROM gestion t
),
--_________
cliente_por_gestionar_dates_1 AS(
        SELECT broker_id, date(updated_at) updated_at, count(status) count_s
            FROM papyrus-data.habi_wh_brokers.lead
            WHERE status in ('','buscando', 'interesado-ver mas opciones', 'interesado-volver a llamar',
            '    pendiente aprobacion habicredit', 'segunda visita', 'interesado-inmueble vendido')
            GROUP BY 1,2
),
cliente_por_gestionar_dates_range AS(
        SELECT t.*, 
        sum(count_s) over (
                PARTITION BY broker_id 
                ORDER BY UNIX_DATE(date(updated_at)) RANGE BETWEEN 5 PRECEDING AND CURRENT ROW) gestion_s
                --ORDER BY DATE_SUB(DATE(updated_at) , INTERVAL 5 DAY)) gestion_s
        FROM cliente_por_gestionar_dates_1 t
        ORDER BY broker_id, updated_at
),
cliente_por_gestionar_dates_2 AS(
        SELECT broker_id, date(updated_at) updated_at, count(status) count_s
            FROM papyrus-data.habi_wh_brokers.lead
            WHERE status in ('aplazado')
            GROUP BY 1,2
),
cliente_por_gestionar_dates_range_2 AS(
        SELECT t.*, 
        sum(count_s) over (
                PARTITION BY broker_id 
                ORDER BY DATE_SUB(DATE(updated_at) , INTERVAL 15 DAY)) gestion_a
        FROM cliente_por_gestionar_dates_2 t
        ORDER BY broker_id, updated_at
),
brokers_con_clientes_gestionar_ AS(
SELECT  l.broker_id, 
        DATE(l.updated_at) updated_at, 
        l.status,
        CASE WHEN c1.gestion_s IS NOT NULL OR c2.gestion_a IS NOT NULL THEN 1 ELSE 0 END client_gestion
FROM `papyrus-data.habi_wh_brokers.lead` l
LEFT JOIN cliente_por_gestionar_dates_range c1 ON c1.broker_id = l.broker_id AND DATE(l.updated_at) = c1.updated_at
LEFT JOIN cliente_por_gestionar_dates_range_2 c2 ON c2.broker_id = l.broker_id AND DATE(l.updated_at) = c2.updated_at
WHERE date(l.updated_at) <= DATE_SUB(CURRENT_DATE(), INTERVAL 2 MONTH)
        AND CASE WHEN c1.gestion_s IS NOT NULL OR c2.gestion_a IS NOT NULL THEN 1 ELSE 0 END = 1
ORDER BY c1.gestion_s DESC, c2.gestion_a DESC
),
brokers_con_clientes_gestionar as (
        SELECT broker_id, updated_at, MAX(client_gestion) client_gestion FROM brokers_con_clientes_gestionar_
        GROUP BY 1,2
        ORDER BY broker_id, updated_at
),

visitas_por_gestionar AS (
      SELECT broker_id, date, count(distinct(id)) count_s FROM `papyrus-data.habi_wh_brokers.visit` vis
      WHERE vis.status IS null or vis.status in ("Confirmada","Reagendada")
      GROUP BY 1,2
),
visitas_gestionar_g as(
 SELECT t.*, 
        sum(count_s) over (
            PARTITION BY broker_id 
            --ORDER BY date desc rows between 1  PRECEDING AND CURRENT ROW) gestion_s
            ORDER BY UNIX_DATE(date) RANGE BETWEEN 1 PRECEDING AND CURRENT ROW) gestion_s
        FROM visitas_por_gestionar t
),
brokers_con_visitas_por_gestionar AS(
      SELECT * FROM visitas_gestionar_g
      WHERE gestion_s > 0
),
con_gestion as(
SELECT safe_cast(broker_id as int64) broker_id , date(fecha) fecha, count(tipo_gestion) count_s
FROM `papyrus-data.habi_wh_analytics.gestion_brokers_v_4` gb 
WHERE fecha_seguimiento is not null AND broker_id IS NOT NULL
group by 1,2),
brokers_con_gestion AS(
  SELECT t.*, 
        sum(count_s) over (
            PARTITION BY broker_id 
            --ORDER BY date desc rows between 1  PRECEDING AND CURRENT ROW) gestion_s
            ORDER BY UNIX_DATE(fecha) RANGE BETWEEN 7 PRECEDING AND CURRENT row) gestion_s
        FROM con_gestion t
),
final_base AS (

SELECT 
  bs.*,
  IF (COALESCE(pg.gestion_s, 0) > 0, 1, 0) broker_por_gestionar,
  IF (COALESCE(cg.client_gestion, 0) > 0, 1, 0) broker_con_clientes_a_gestionar,
  IF (COALESCE(vg.gestion_s, 0) > 0, 1, 0) broker_con_visitas_a_gestionar,
  IF (COALESCE(bg.gestion_s, 0) > 0, 1, 0) broker_con_gestion
FROM QUERY_RETOOL_DATE bs
LEFT JOIN brokers_por_gestionar pg ON bs.broker_id = pg.broker_id AND bs.date = pg.fecha_seguimiento
LEFT JOIN brokers_con_clientes_gestionar cg ON bs.broker_id = cg.broker_id and bs.date = cg.updated_at
LEFT JOIN brokers_con_visitas_por_gestionar vg ON bs.broker_id = vg.broker_id and bs.date = vg.date
LEFT JOIN brokers_con_gestion bg ON bs.broker_id = bg.broker_id and bs.date = bg.fecha
)
SELECT * FROM final_base
order by broker_id, date

--select distinct broker_por_gestionar,broker_con_clientes_a_gestionar,broker_con_visitas_a_gestionar, broker_con_gestion
--FROM final_base
-- SELECT *,
-- broker_por_gestionar+ roker_con_clientes_a_gestionar + broker_con_visitas_a_gestionar check
-- FROM final_base
-- ORDER BY broker_por_gestionar+ broker_con_clientes_a_gestionar + broker_con_visitas_a_gestionar DESC



















