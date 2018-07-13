SELECT          s.shipment_id                                            AS "SHIPMENT_ID",
                ewt.work_type                                            AS "WORK_TYPE",
                To_char(s.imported_date, 'MM/DD/YY HH:MI:SS AM')         AS "EXPORTED_TIME",
                picking.authorizer                                       AS "WHO TRIGGERED PICK-X?",
                To_char(picking.authorized_date, 'MM/DD/YY HH:MI:SS AM') AS "PICK_EXCEPTIONED",
                packing.pack_failer                                      AS "WHO TRIGGERED PACK-X?",
                packing.pack_fail_time                                   AS "PACK_EXCEPTIONED",
                CASE
                                WHEN picker.first_name
                                                                ||' '
                                                                || picker.last_name IS NULL THEN picking.authorizer
                                WHEN picker.first_name
                                                                ||' '
                                                                || picker.last_name IS NOT NULL THEN picker.first_name
                                                                ||' '
                                                                || picker.last_name
                END AS "PICKER",
                CASE
                                WHEN picking.cause_of_error IS NULL THEN To_char(picker.picking_completed_date, 'MM/DD/YY HH:MI:SS AM')
                                WHEN picking.cause_of_error IS NOT NULL THEN picking.cause_of_error
                END AS "PICK_COMPLETE_TIME",
                CASE
                                WHEN passed_pack.packer IS NOT NULL THEN passed_pack.packer
                                WHEN packing.packing_complete_date IS NULL THEN packing.pack_failer
                END AS "PACKER",
                CASE
                                WHEN packing.pack_fail_time IS NULL THEN To_char(passed_pack.packing_complete_date, 'MM/DD/YY HH:MI:SS AM')
                                WHEN packing.pack_fail_time IS NOT NULL THEN packing.input_data
                END             AS "PACK_COMPLETE",
                oversold."NAME" AS "OVERSOLD?",
                s.shipped_date,
                s.tracking_num
FROM            shipment S
LEFT OUTER JOIN exporting_flags EF
ON              s.shipment_id = ef.shipment_id
LEFT OUTER JOIN exporting_work_type EWT
ON              ewt.id = ef.work_type_id
LEFT OUTER JOIN
                (
                           SELECT     sgsk.shipment_id AS ship_id,
                                      sgsk.exception   AS cause_of_error,
                                      sgsk.authorized_by,
                                      sgsk.authorized_date,
                                      ad.first_name
                                                 ||' '
                                                 || ad.last_name AS authorizer
                           FROM       sg_sku_state SGSK
                           INNER JOIN administrators AD
                           ON         sgsk.authorized_by = ad.id
                           WHERE      sgsk.is_exception = 1 )PICKING
ON              picking.ship_id = s.shipment_id
LEFT OUTER JOIN
                (
                           SELECT     sgpss.packer_id,
                                      ad.first_name
                                                 ||' '
                                                 || ad.last_name AS pack_failer,
                                      Max(sgpss.shipment_id)     AS ship_id,
                                      sgpss.packing_complete_date,
                                      To_char(sgpss.date_created, 'MM/DD/YY HH:MI:SS AM')AS pack_fail_time,
                                      CASE
                                                 WHEN sgpss.is_exception = 1
                                                 AND        sgpss.passed_pack_qa = 0 THEN 'FAILED PACKING'
                                      END AS "PACKING_STATE",
                                      sgpss.is_exception,
                                      sgpss.passed_pack_qa,
                                      sl.input_data
                           FROM       sg_packing_shipment_state SGPSS
                           INNER JOIN administrators AD
                           ON         sgpss.packer_id = ad.id
                           INNER JOIN sg_log SL
                           ON         sl.shipment_id = sgpss.shipment_id
                           WHERE      sgpss.is_exception = 1
                           AND        sgpss.passed_pack_qa = 0
                           AND        sl.category = 16
                           AND        sl.result_type = 2
                           AND        sgpss.date_created >= '01-JAN-18'
                           GROUP BY   sgpss.packer_id,
                                      ad.first_name
                                                 ||' '
                                                 || ad.last_name,
                                      sgpss.packing_complete_date,
                                      To_char(sgpss.date_created, 'MM/DD/YY HH:MI:SS AM'),
                                      CASE
                                                 WHEN sgpss.is_exception = 1
                                                 AND        sgpss.passed_pack_qa = 0 THEN 'FAILED PACKING'
                                      END,
                                      sgpss.is_exception,
                                      sgpss.passed_pack_qa,
                                      sl.input_data
                           ORDER BY   To_char(sgpss.date_created, 'MM/DD/YY HH:MI:SS AM') DESC)PACKING
ON              packing.ship_id = s.shipment_id
LEFT OUTER JOIN
                (
                                SELECT          *
                                FROM            sg_shipment_state SGSS
                                LEFT OUTER JOIN administrators AD2
                                ON              ad2.id = sgss.picker_id)PICKER
ON              picker.shipment_id = s.shipment_id
LEFT OUTER JOIN
                (
                           SELECT     sgpss.packer_id,
                                      ad.first_name
                                                 ||' '
                                                 || ad.last_name AS packer,
                                      sgpss.shipment_id,
                                      sgpss.packing_complete_date
                           FROM       sg_packing_shipment_state SGPSS
                           INNER JOIN administrators AD
                           ON         sgpss.packer_id = ad.id
                           WHERE      sgpss.is_exception = 0
                           AND        sgpss.passed_pack_qa = 1
                           AND        sgpss.date_created >= '01-JAN-18'
                           ORDER BY   To_char(sgpss.date_created, 'MM/DD/YY HH:MI:SS AM') DESC)PASSED_PACK
ON              passed_pack.shipment_id = s.shipment_id
LEFT OUTER JOIN
                (
                                SELECT          s.order_id
                                                                || '-'
                                                                || s.shipment_number AS "ORDER_NUMBER",
                                                s.imported_date::date                AS "PROCESSED",
                                                s.shipment_id                        AS "SHIPMENT_ID",
                                                oe.NAME                              AS "NAME",
                                                pl.expected_send_date::              date,
                                                pl.expected_delivery_date::          date
                                FROM            shipment s
                                LEFT OUTER JOIN order_shipment os
                                ON              s.shipment_id = os.shipment_id
                                LEFT OUTER JOIN order_exception oe
                                ON              os.order_exception_id = oe.id,
                                                proship_shipment_lookup pl
                                WHERE           oe.NAME = 'Oversold'
                                AND             s.shipment_id = pl.shipment_id)OVERSOLD
ON              oversold."SHIPMENT_ID" = s.shipment_id
WHERE           s.is_cancelled = 0
AND             s.is_drop_ship = 0
AND             s.shipped_date IS NULL

AND             s.imported_date::date >= to_date('2018-07-13', 'YYYY-MM-DD')
AND             s.imported_date::date <= to_date('2018-07-13', 'YYYY-MM-DD')
ORDER BY        To_char(s.imported_date, 'MM/DD/YY') DESC