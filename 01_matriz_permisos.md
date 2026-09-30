# 01 - Access Control Matrix & Privilege Justification

This document outlines the security and access control policy designed for the `logitrack_lab` database under the **Principle of Least Privilege**.

## Privilege Matrix

| Business Profile | Group Role (NOLOGIN) | CONNECT (Database) | USAGE (Schemas) | SELECT (Read) | INSERT / UPDATE / DELETE (Write) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Warehouse** | `rol_almacen_logitrack` | `logitrack_lab` | `logistica` | `logistica.envios` | **UPDATE:** `logistica.envios(estado)` |
| **Expeditions** | `rol_expediciones_logitrack` | `logitrack_lab` | `logistica` | `logistica.clientes`, `logistica.envios` | **UPDATE:** `logistica.envios(id_repartidor, estado)` |
| **Billing** | `rol_facturacion_logitrack` | `logitrack_lab` | `logistica` | `logistica.envios`, `logistica.facturas`, `logistica.v_clientes_seguros` | **INSERT, UPDATE, DELETE:** `logistica.facturas` |
| **Supervision** | `rol_supervision_logitrack` | `logitrack_lab` | `logistica` | `logistica.v_estado_general_envios`, `logistica.v_supervision_cuadro_mando` | **None** *(Restricted to authorized views)* |
| **Auditing** | `rol_auditoria_logitrack` | `logitrack_lab` | `logistica`, `audit` | `logistica.*`, `audit.cambios_facturas`, `logistica.v_clientes_seguros` | **None** *(Strict read-only policy)* |

---

## Technical and Operational Justification

### 1. Warehouse Profile (`rol_almacen_logitrack`)
* **Justification:** Daily tasks center around the physical preparation of packages. It requires visibility of shipments to know what to pack, but must only modify the `estado` column (to move status from `pendiente` to `preparado`). Financial records (invoices) or driver data are completely restricted.

### 2. Expeditions Profile (`rol_expediciones_logitrack`)
* **Justification:** Coordinates routes and assigns carriers. It requires visibility over customer information and packages ready to leave. Writing capabilities are strictly limited to the `id_repartidor` and `estado` columns within the shipments table. Modifying fiscal data, billing amounts, or master accounting parameters is forbidden.

### 3. Billing Profile (`rol_facturacion_logitrack`)
* **Justification:** Manages the financial flow of the laboratory. It tracks completed shipments to issue corresponding customer transactions. It has full writing control over the `facturas` table but cannot alter master records of drivers or vehicles to prevent internal fraud. Due to the deployment of **symmetric column encryption** via `pgcrypto` on client PII (`nif`, `email`, `telefono`, `iban`), this role is uniquely granted read privileges over the secure decryption view `v_clientes_seguros` to perform explicit financial validation.

### 4. Supervision Profile (`rol_supervision_logitrack`)
* **Justification:** Monitors overall business performance through management dashboards. To satisfy compliance, corporate privacy, and data isolation requirements, this profile works exclusively through unprivileged reporting views. Direct access to baseline transactional tables is blocked by the core database engine, masking customer NIFs, telephone numbers, financial details, and bank account values.

### 5. Auditing Profile (`rol_auditoria_logitrack`)
* **Justification:** In charge of regulatory compliance and data security integrity. It requires a strict read-only policy (`SELECT`) across all operational business components, historical logs, and security tracking definitions. It is completely restricted from altering any records, ensuring the audit trail remains immutable. It holds read privileges over the secure decryption view `v_clientes_seguros` to perform explicit forensic data audits when required.
