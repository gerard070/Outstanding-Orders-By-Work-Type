select work_type, count_of_shipments, concat((round(((Count_Of_Shipments/total)*100),2))::varchar, '%') as Percentage_Of_Total

from
  (
    SELECT
      (SELECT sum(count_of_shipments)
       FROM
         (
           SELECT
             count(s.shipment_id) AS Count_Of_Shipments,
             ewt.work_type
           FROM shipment S
             JOIN exporting_flags EF
               ON S.shipment_id = ef.shipment_id
             JOIN exporting_work_type EWT
               ON ewt.id = ef.work_type_id
           WHERE S.shipped_date IS NULL
                 AND (S.tracking_num IS NULL OR S.tracking_num = '')
                 AND S.settled IS NOT NULL
                 AND S.is_drop_ship != 1
                 AND S.is_cancelled != 1
                 AND ewt.work_type IS NOT NULL
                 AND work_type != 'Backorder Pending'
                 AND work_type != 'Email Gift Certificates'
                 AND work_type != 'Flags Pending (exclusions)'
                 AND work_type != 'Single Line Single Unit Backorder'
                 AND work_type != 'Single Line Unit Backorder'
           GROUP BY ewt.work_type
         ) All_Orders
      ) AS total,
      work_type,
      Count_Of_Shipments
    FROM (
           SELECT
             count(s.shipment_id) AS Count_Of_Shipments,
             ewt.work_type
           FROM shipment S
             JOIN exporting_flags EF
               ON S.shipment_id = ef.shipment_id
             JOIN exporting_work_type EWT
               ON ewt.id = ef.work_type_id
           WHERE S.shipped_date IS NULL
                 AND (S.tracking_num IS NULL OR S.tracking_num = '')
                 AND S.settled IS NOT NULL
                 AND S.is_drop_ship != 1
                 AND S.is_cancelled != 1
                 AND ewt.work_type IS NOT NULL
                 AND work_type != 'Backorder Pending'
                 AND work_type != 'Email Gift Certificates'
                 AND work_type != 'Flags Pending (exclusions)'
                 AND work_type != 'Single Line Single Unit Backorder'
                 AND work_type != 'Single Line Unit Backorder'
           GROUP BY ewt.work_type
         ) All_orders

  ) final_table


