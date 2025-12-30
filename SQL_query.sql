CREATE DATABASE supply_chain_analysis;
 -- 3 tables I used -- 
 
SELECT * FROM  inventory_appliances;
SELECT * FROM shipments_appliances;
SELECT * FROM suppliers_appliances;

-- shows each supplier’s delayed shipments and their percentage of total delays--
SELECT sh.supplier_id, su.location, su.supplier_name,
	COUNT(*) AS delayed_shipments, ROUND(COUNT(*) * 100.0/ SUM(COUNT(*)) OVER(),2) AS pct_total
FROM shipments_appliances sh
JOIN suppliers_appliances su
	ON sh.supplier_id = su.supplier_id
WHERE status = "Delayed" 
GROUP BY sh.supplier_id, su.supplier_name, su.location
ORDER BY delayed_shipments DESC;
	-- END --

-- calculate the total income of all the products that was successfull delivered
SELECT i.item_name, COALESCE(i.category, 'Unknown') AS category, s.status,SUM(s.quantity) AS Total_Quantity,
SUM(i.price * s.quantity) AS Total_sale,
COUNT(*) AS Total_Shipments
FROM inventory_appliances i
JOIN shipments_appliances s
	ON i.item_id = s.item_id
WHERE s.status = 'Delivered'
GROUP BY i.item_name, category
ORDER BY Total_sale DESC;	
-- END--

-- compute average days it takes each supplier to deliver
WITH supplier_leadtime AS (
		SELECT 
			supplier_id,
			AVG(DATEDIFF(delivery_date, shipment_date)) AS avg_lead_days
		FROM shipment_appliances2
		WHERE status = 'Delivered'
		  AND delivery_date IS NOT NULL
		  AND shipment_date IS NOT NULL
          AND delivery_date > shipment_date
		GROUP BY supplier_id
),
predicted_arrival AS (
    SELECT 
        sh.shipment_id, sh.item_id, i.item_name, sh.supplier_id, s.supplier_name,
        sh.quantity, sh.shipment_date, sh.status,
        COALESCE(FLOOR(sl.avg_lead_days), 7) AS avg_lead_days, 
        DATE_ADD(sh.shipment_date, INTERVAL COALESCE(FLOOR(sl.avg_lead_days), 7) DAY) AS predicted_arrival_date
    FROM shipment_appliances2 sh
    LEFT JOIN supplier_leadtime sl
           ON sh.supplier_id = sl.supplier_id
    LEFT JOIN suppliers_appliances s	
           ON sh.supplier_id = s.supplier_id
    LEFT JOIN inventory_appliances i
           ON sh.item_id = i.item_id
    WHERE sh.status IN ('Pending', 'Delayed')
)
SELECT *
FROM predicted_arrival
ORDER BY predicted_arrival_date;
-- END--

-- identifies which suppliers have the most delayed shipments--
WITH delay_shipment AS(
	SELECT sh.shipment_id, sh.supplier_id, s.supplier_name, sh.status, sh.delivery_date
	FROM shipments_appliances sh
    JOIN suppliers_appliances s
		ON sh.supplier_id = s.supplier_id
	WHERE status = "Delayed"	
),
  total_delay AS(
	SELECT shipment_id, supplier_name, supplier_id, delivery_date,
    COUNT(*) OVER (PARTITION BY supplier_id) AS number_delay
    FROM delay_shipment
    )
SELECT supplier_id, supplier_name, SUM(number_delay) AS total_delay_shipment
FROM total_delay
GROUP BY supplier_id, supplier_name
ORDER BY total_delay_shipment DESC;
-- END --

-- generates insights on supplier performance by computing total delivered item costs per location--
SELECT i.item_id, i.item_name, i.category, i.stock, s.location, sh.status,i.price,
		SUM(i.price) OVER (PARTITION BY s.location ORDER BY i.item_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)  AS cumulative_of_price
FROM inventory_appliances i
JOIN suppliers_appliances s
	ON i.supplier_id = s.supplier_id
JOIN shipments_appliances sh
	ON i.supplier_id = sh.supplier_id
WHERE  sh.status = "Delivered";
-- END --

-- identify inventory item at risk of stockout by comparing total stock and total reorder_level--
SELECT  item_name, category, SUM(stock) AS total_stock,SUM(reorder_level) AS total_reorder_level,
	CASE 
		WHEN SUM(stock) < SUM(reorder_level) THEN 'Critical'
		WHEN SUM(stock) > SUM(reorder_level) THEN 'Good'
		ELSE 'Adequate'
	END AS stock_status
FROM inventory_appliances
GROUP BY category, item_name
ORDER BY total_stock, total_reorder_level DESC;
   -- END --

-- Computes the overall total price for all items in each category --
SELECT category,
		SUM(CASE WHEN item_name	= "Dishwasher" THEN price ELSE 0 END) AS Dishwasher_Total_Price,
        SUM(CASE WHEN item_name	= "Water Heater" THEN price ELSE 0 END) AS WaterHeater_Total_Price,
        SUM(CASE WHEN item_name	= "Vacuum Cleaner" THEN price ELSE 0 END) AS Iron_Total_Price,
        SUM(CASE WHEN item_name	= "Mixer" THEN price ELSE 0 END) AS Mixer_Total_Price,
        SUM(CASE WHEN item_name	= "LED TV" THEN price ELSE 0 END) AS Toaster_Total_Price,
        SUM(CASE WHEN item_name	= "Dehumidifier" THEN price ELSE 0 END) AS Dehumidifier_Total_Price,
        -- calculate the total of selected item 
        SUM(CASE WHEN item_name IN ("Dishwasher","Water Heater","Vacuum Cleaner","Mixer","LED TV","Dehumidifier")
			THEN price ELSE 0 END ) AS OverAll_Total_Price
FROM inventory_appliances
GROUP BY category
ORDER BY category
		-- END --


    
		
 










