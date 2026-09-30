# Logistics System, Access Permissions, and Automated Auditing (logitrack_lab)

This project implements the design, securitization, and audit control of a relational database for managing shipments and billing in **PostgreSQL**. The architecture is strictly grounded on the **Principle of Least Privilege** and the strict separation of duties.

👉 *Para la versión en español, consulta el archivo [README.es.md](README.es.md).*

---

## 📁 Project Structure

The repository is organized into the following sequential modules:

*   **`01_matriz_permisos.md`**: Conceptual definition and design of the access control matrix.
*   **`02_roles_permisos_pruebas.sql`**: Creation of group roles, operational login users, specific table/column privilege definitions, and baseline test validation scripts.
*   **`03_vista_supervision.sql`**: Definition of the depersonalized view optimized for the supervision profile.
*   **`04_auditoria_facturas.sql`**: Audit trail mechanism utilizing database triggers in `PL/pgSQL` with isolated execution properties (`SECURITY DEFINER`).
*   **`05_pruebas.sql`**: Functional validation block testing permitted and denied actions through session context switching (`SET ROLE`).
*   **`06_cifrado_pgcrypto.sql`**: Implementation of multi-field symmetric encryption using `pgcrypto`, automated triggers, legacy data migration, and explicit view permissions.

---

## 📊 1. Access Control Matrix & Privilege Justification

Five distinct business access profiles have been configured using group roles (`NOLOGIN`) and specific operational users (`LOGIN`). None of these operational accounts hold administrative privileges (`NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`).

### Privilege Allocation Overview

| Business Profile | Group Role (NOLOGIN) | CONNECT (Database) | USAGE (Schemas) | SELECT (Read) | INSERT / UPDATE / DELETE (Write) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Warehouse** | `rol_almacen_logitrack` | `logitrack_lab` | `logistica` | `logistica.envios` | **UPDATE:** `logistica.envios(estado)` |
| **Expeditions** | `rol_expediciones_logitrack` | `logitrack_lab` | `logistica` | `logistica.clientes`, `logistica.envios` | **UPDATE:** `logistica.envios(id_repartidor, estado)` |
| **Billing** | `rol_facturacion_logitrack` | `logitrack_lab` | `logistica` | `logistica.envios`, `logistica.facturas`, `logistica.v_clientes_seguros` | **INSERT, UPDATE, DELETE:** `logistica.facturas` |
| **Supervision** | `rol_supervision_logitrack` | `logitrack_lab` | `logistica` | `logistica.v_supervision_cuadro_mando`, `logistica.v_estado_general_envios` | **None** *(Restricted to operational views)* |
| **Audit** | `rol_auditoria_logitrack` | `logitrack_lab` | `logistica`, `audit` | `logistica.*`, `audit.cambios_facturas`, `logistica.v_clientes_seguros` | **None** *(Strict read-only policy)* |

---

### Technical and Operational Justification

1. **Warehouse Profile (`rol_almacen_logitrack`)**
   * **Justification:** Daily tasks center around the physical preparation of packages. It requires visibility of shipments to know what to pack, but must only modify the `estado` (status) column to advance a shipment from `pendiente` to `preparado`. Financial data (invoices) or personnel data (drivers) are completely restricted.
2. **Expeditions Profile (`rol_expediciones_logitrack`)**
   * **Justification:** Coordinates routes and assigns carriers. It requires visibility over customer information and packages ready to leave. Writing permissions are specifically limited to the `id_repartidor` and `estado` columns within the shipments table. Modifying fiscal data or invoice amounts is strictly forbidden.
3. **Billing Profile (`rol_facturacion_logitrack`)**
   * **Justification:** Manages the financial flow of the laboratory. It must track completed shipments to issue corresponding payments. It has full writing control over the `facturas` table but cannot alter master records of clients or vehicles to prevent internal fraud. It holds explicit access to decrypt and read sensitive customer metrics via secured views.
4. **Supervision Profile (`rol_supervision_logitrack`)**
   * **Justification:** Monitors business performance through unified dashboards. To comply with data isolation and depersonalization of sensitive data, it works exclusively through specialized views (`v_supervision_cuadro_mando` / `v_estado_general_envios`). Direct access to base tables is blocked by the engine, masking NIF, IBAN, phone numbers, and financial details.
5. **Auditing Profile (`rol_auditoria_logitrack`)**
   * **Justification:** In charge of regulatory compliance and data security. It requires a strict read-only policy (`SELECT`) across the entire business ecosystem and the audit log table. Altering any record is absolutely prohibited, guaranteeing that the audit trail remains completely immutable.

---

## 🔒 2. Applied Database Security

### Specific Column-Level Privileges (Targeted Security)
To rigorously enforce security policies, operational roles are restricted from executing broad modifications on core tables:
* **Warehouse** can only modify the specific `estado` column in the `envios` table.
* **Expeditions** can only modify specific `id_repartidor` and `estado` columns in the `envios` table.

### Data Isolation for Supervision
The supervision profile interfaces solely with authorized operational views. These views intentionally **omit** sensitive, corporate, or financial records such as:
* Customer tax identifiers (NIF).
* Telephone numbers or bank account details (IBAN).
* Financial amounts tied to specific customer invoices.

### Advanced Symmetric Encryption (`pgcrypto`)
To safeguard sensitive customer Personally Identifiable Information (PII) against direct disk exposure or database backup leaks, advanced column encryption is applied to `nif`, `email`, `telefono`, and `iban`:
* **Symmetric Encryption (`pgp_sym_encrypt`):** Converts raw text data into secure binary payloads (`BYTEA`) using a centralized laboratory secret key.
* **Automatic Encryption Trigger:** A database trigger executes automatically `BEFORE INSERT OR UPDATE` on the `clientes` table. It intercepts plaintext inputs, encrypts them, and overwrites the base text storage with placeholder strings (`*** PROTECTED ***`), preventing accidental raw storage.
* **Decryption View (`v_clientes_seguros`):** Reconstructs original values for authorized entities using `pgp_sym_decrypt`. Access is explicitly bound to the **Billing** and **Auditing** profiles via dedicated database permissions, leaving other operational roles restricted.

---

## 📋 3. Automated Auditing System (`audit`)

Management requires clear accountability regarding financial modifications. A detached "black box" logging mechanism has been designed within the `audit` schema:

* **Log Table:** `audit.cambios_facturas` tracks unique log identifiers, the executing database user, exact timestamp, operation type (`INSERT`/`UPDATE`/`DELETE`), and a complete state capture of old versus new financial amounts and statuses.
* **PL/pgSQL Trigger Function:** Automatically fires after any mutation takes place on the `logistica.facturas` table.
* **Security Definer Isolation Mechanism:** The trigger function runs under the administrative security privileges of its creator (`SECURITY DEFINER`). This allows the billing user to record audit logs transparently without requiring explicit or invasive write privileges over the dedicated `audit` schema.

### Audit Tamper Prevention
Operational profiles are **strictly prohibited from updating or deleting** any records within the audit historical tables. This enforces the **Principle of Non-Repudiation**: no operator can tamper with or erase the trail of their own actions, protecting the system against internal fraud.

---

## 🚀 4. Deployment and Validation

To validate the security infrastructure in a local environment, execute the files in chronological order from `01` to `06`.

### Operational Context Validation Example
The verification scripts leverage identity context switching (`SET ROLE`) to simulate real business workflows:

```sql
-- Switch context to the warehouse operator
SET ROLE almacen1;
-- ALLOWED: Modifying the logistical status of a package
UPDATE logistica.envios SET estado = 'preparado' WHERE id_envio = 1; -- OK
-- DENIED: Attempting to modify the destination address
-- UPDATE logistica.envios SET destino = 'Madrid' WHERE id_envio = 1;   -- ERROR: Permission Denied
RESET ROLE;

-- Switch context to the billing operator
SET ROLE facturacion1;
-- ALLOWED: Querying decrypted customer parameters via the secure view
SELECT nif_original, iban_original FROM logistica.v_clientes_seguros WHERE id_cliente = 1; -- OK
RESET ROLE;
```
