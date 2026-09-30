# Sistema de Logística, Permisos de Acceso y Auditoría Automatizada (logitrack_lab)

Este proyecto implementa el diseño, la securización y el control de auditoría de una base de datos relacional para la gestión de envíos y facturación en **PostgreSQL**. La arquitectura se basa estrictamente en el **Principio de Menor Privilegio** y la separación de funciones.

👉 *You can find the English version of this documentation in the [README.md](README.MD) file.*

---

## 📁 Estructura del Proyecto

El repositorio está organizado en los siguientes módulos secuenciales:

*   **`01_matriz_permisos.md`**: Definición conceptual y diseño de la matriz de accesos.
*   **`02_roles_permisos_pruebas.sql`**: Creación de roles de grupo, usuarios operacionales, definición de permisos específicos por tablas/columnas y scripts de validación inicial.
*   **`03_vista_supervision.sql`**: Definición de la vista despersonalizada para el perfil de supervisión.
*   **`04_auditoria_facturas.sql`**: Mecanismo de auditoría mediante triggers en `PL/pgSQL` con propiedades de aislamiento (`SECURITY DEFINER`).
*   **`05_pruebas.sql`**: Bloque secuencial de validación de operaciones permitidas y denegadas mediante el cambio de contextos (`SET ROLE`).
*   **`06_cifrado_pgcrypto.sql`**: Implementación de cifrado simétrico multi-campo utilizando `pgcrypto`, triggers automáticos, migración de datos heredados y permisos explícitos sobre la vista segura.

---

## 📊 1. Matriz de Control de Accesos y Justificación de Permisos

Se han configurado cinco perfiles de accesos del negocio utilizando roles de grupo (`NOLOGIN`) y usuarios específicos (`LOGIN`). Ninguno de estos usuarios posee privilegios administrativos (`NOSUPERUSER`, `NOCREATEDB`, `NOCREATEROLE`).

### Vista General de Asignación de Privilegios

| Perfil de Negocio | Rol de Grupo (NOLOGIN) | CONNECT (Base de datos) | USAGE (Esquemas) | SELECT (Lectura) | INSERT / UPDATE / DELETE (Escritura) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Almacén** | `rol_almacen_logitrack` | `logitrack_lab` | `logistica` | `logistica.envios` | **UPDATE:** `logistica.envios(estado)` |
| **Expediciones** | `rol_expediciones_logitrack` | `logitrack_lab` | `logistica` | `logistica.clientes`, `logistica.envios` | **UPDATE:** `logistica.envios(id_repartidor, estado)` |
| **Facturación** | `rol_facturacion_logitrack` | `logitrack_lab` | `logistica` | `logistica.envios`, `logistica.facturas`, `logistica.v_clientes_seguros` | **INSERT, UPDATE, DELETE:** `logistica.facturas` |
| **Supervisión** | `rol_supervision_logitrack` | `logitrack_lab` | `logistica` | `logistica.v_supervision_cuadro_mando`, `logistica.v_estado_general_envios` | **Ninguno** *(Acceso restringido a las vistas operativas)* |
| **Auditoría** | `rol_auditoria_logitrack` | `logitrack_lab` | `logistica`, `audit` | `logistica.*`, `audit.cambios_facturas`, `logistica.v_clientes_seguros` | **Ninguno** *(Lectura estricta sin alteración de datos)* |

---

### Justificación Técnica y Operativa

1. **Perfil Almacén (`rol_almacen_logitrack`)**
   * **Justificación:** Su labor diaria se centra en la preparación física de paquetes. Requiere visibilidad de los envíos para saber qué empacar, pero solo debe poder modificar la columna específica `estado` (para pasar de `pendiente` a `preparado`). Se le deniega por completo el acceso a datos financieros (facturas) o de personal (repartidores).
2. **Perfil Expediciones (`rol_expediciones_logitrack`)**
   * **Justificación:** Coordina las rutas y asigna transportistas. Necesita ver la información de los clientes y los paquetes listos para salir. Su capacidad de escritura se restringe de forma específica por columnas a `id_repartidor` y `estado` en la tabla de envíos. Tiene prohibido modificar datos fiscales o importes.
3. **Perfil Facturación (`rol_facturacion_logitrack`)**
   * **Justificación:** Administra el flujo financiero del laboratorio. Debe ver qué envíos se han completado para emitir sus cobros correspondientes. Tiene control total de escritura sobre la tabla `facturas`, pero no puede alterar datos maestros de clientes o vehículos para prevenir fraudes. Cuenta con acceso explícito para descifrar y consultar métricas sensibles de clientes mediante vistas protegidas.
4. **Perfil Supervisión (`rol_supervision_logitrack`)**
   * **Justificación:** Monitorea el rendimiento del negocio mediante un cuadro de mando. Para cumplir con el principio de aislamiento y despersonalización de datos sensibles, trabaja exclusivamente sobre vistas autorizadas. El motor le bloquea el acceso directo a las tablas base, ocultando NIF, IBAN, teléfonos e importes financieros.
5. **Perfil Auditoría (`rol_auditoria_logitrack`)**
   * **Justificación:** Encargado del cumplimiento normativo y la seguridad. Requiere una política estricta de **Solo Lectura (`SELECT`)** sobre todo el ecosistema de negocio y la tabla de logs. Tiene prohibido de forma absoluta alterar cualquier registro, garantizando que el rastro de auditoría sea inmutable.

---

## 🔒 2. Seguridad Aplicada

### Privilegios Específicos a Nivel de Columna (Seguridad Focalizada)
Para cumplir rigurosamente con las políticas de seguridad, los roles operativos no tienen acceso total de modificación sobre las tablas principales:
* **Almacén** sólo puede modificar la columna determinada `estado` de la tabla `envios`.
* **Expediciones** sólo puede modificar las columnas determinadas `id_repartidor` y `estado` en la tabla `envios`.

### Aislamiento de Datos para Supervisión
El perfil de supervisión trabaja de manera exclusiva a través de vistas operacionales autorizadas. Estas vistas **omiten** cualquier dato sensible, corporativo o fiscal como:
* NIF de clientes.
* Teléfonos o números de cuenta bancaria (IBAN).
* Importes económicos de las facturas.

### Cifrado Simétrico Avanzado (`pgcrypto`)
Para salvaguardar la Información de Identificación Personal (PII) de los clientes contra accesos directos al disco o filtraciones en copias de seguridad, se aplica un cifrado avanzado en las columnas `nif`, `email`, `telefono` e `iban`:
* **Cifrado Simétrico (`pgp_sym_encrypt`):** Convierte los datos legibles en cadenas binarias (`BYTEA`) utilizando una clave secreta centralizada del laboratorio.
* **Trigger de Cifrado Automático:** Un trigger en la base de datos se ejecuta de forma automatizada `BEFORE INSERT OR UPDATE` en la tabla `clientes`. Intercepta los textos planos entrantes, los cifra y sobrescribe las columnas de almacenamiento base con marcadores (`*** PROTEGIDO ***`), previniendo el almacenamiento accidental de datos en claro.
* **Vista de Descifrado (`v_clientes_seguros`):** Reconstructe los valores originales mediante `pgp_sym_decrypt`. El acceso está restringido de forma explícita a los perfiles de **Facturación** y **Auditoría** mediante permisos dedicados del motor, bloqueando al resto de roles operativos.

---

## 📋 3. Sistema de Auditoría (`audit`)

La dirección de la organización requiere saber exactamente quién altera los estados financieros. Para ello, se ha diseñado una "caja negra" en el esquema `audit`:

* **Tabla de Logs:** `audit.cambios_facturas` registra el identificador único, usuario ejecutor, fecha y hora exacta, operación (`INSERT`/`UPDATE`/`DELETE`), así como los estados e importes anteriores y posteriores.
* **Trigger en PL/pgSQL:** Se dispara de forma automatizada tras cualquier alteración de la tabla `logistica.facturas`.
* **Mecanismo Security Definer:** La función del disparador se ejecuta con los privilegios de su creador (`SECURITY DEFINER`). Esto permite que el usuario de facturación registre el log de auditoría de forma transparente sin necesidad de tener permisos de escritura directos sobre el esquema de auditoría.

### Justificación de Restricciones en la Auditoría
Los perfiles operativos tienen **estrictamente prohibido modificar o borrar** el histórico de auditoría. Esto garantiza el **Principio de No Repudio**: ningún operador puede manipular o eliminar el rastro de sus propias acciones o errores, blindando el sistema contra fraudes internos.

---

## 🚀 4. Despliegue y Pruebas

Para validar todo el ecosistema de seguridad en un entorno local o de laboratorio, ejecute los archivos en orden cronológico del `01` al `06`.

### Ejemplo de Traza de Validación de Contextos
Los scripts de verificación utilizan el cambio de identidad bajo demanda (`SET ROLE`) para simular los flujos de trabajo del negocio:

```sql
-- Cambiar al contexto del usuario almacen1
SET ROLE almacen1;
-- PERMITIDO: Actualizar el estado logístico de un envío
UPDATE logistica.envios SET estado = 'preparado' WHERE id_envio = 1; -- OK
-- DENEGADA: Intentar cambiar el destino del paquete (Provoca error de permisos)
-- UPDATE logistica.envios SET destino = 'Madrid' WHERE id_envio = 1;   -- ERROR: Permiso denegado
RESET ROLE;

-- Cambiar al contexto del usuario facturacion1
SET ROLE facturacion1;
-- PERMITIDO: Consultar la información descifrada desde la vista segura
SELECT nif_original, iban_original FROM logistica.v_clientes_seguros WHERE id_cliente = 1; -- OK
RESET ROLE;
```
