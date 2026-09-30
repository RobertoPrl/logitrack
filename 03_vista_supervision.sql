-----------------------------------------------------------------------------------------
-- PROJECT: logitrack_lab
-- MODULE: 03_vista_supervision.sql
-- DESCRIPTION: Creation of secure views for data hiding and user validation.
-----------------------------------------------------------------------------------------

-- =======================================================================================
-- TAREA 4 · VISTA DE SEGURIDAD PARA SUPERVISION (SECURITY VIEW FOR SUPERVISION PROFILE)
-- =======================================================================================

-- 1. Create a specialized data view to show shipment tracking without exposing sensitive details
CREATE OR REPLACE VIEW logistica.v_estado_general_envios AS
SELECT 
    e.id_envio,
    c.nombre AS nombre_cliente,
    e.destino,
    e.estado AS estado_envio,
    r.nombre AS nombre_repartidor,
    e.fecha_envio
FROM logistica.envios e
JOIN logistica.clientes c ON e.id_cliente = c.id_cliente
LEFT JOIN logistica.repartidores r ON e.id_repartidor = r.id_repartidor;

-- 2. Provide read access exclusively to the management role
GRANT SELECT ON logistica.v_estado_general_envios TO rol_supervision_logitrack;


-- =======================================================================================
-- PRUEBAS DE ACCESO (USER ACCESS AND RESTRICTION VERIFICATION)
-- =======================================================================================

-- Switch database session to the supervisor account context
SET ROLE supervisor1;

-- ALLOWED ACTION: Retrieve consolidated status reporting from the authorized view
SELECT * FROM logistica.v_estado_general_envios;

-- DENIED ACTION: Attempt to scan underlying tables containing financial data
-- The following command is blocked by the engine rules and will trigger a permission error:
-- SELECT * FROM logistica.facturas;

-- Revert the session context back to database administrator
RESET ROLE;
