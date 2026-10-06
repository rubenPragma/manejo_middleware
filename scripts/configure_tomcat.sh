#!/bin/bash
set -euo pipefail

# Script de configuración inicial de Apache Tomcat
# Optimizado para cargas de trabajo de aplicación de banca digital
# Configura parámetros de JVM, pooling de conexiones y seguridad

readonly SCRIPT_VERSION="1.0.0"
readonly TOMCAT_VERSION="9.0.83"
readonly TOMCAT_USER="tomcat"
readonly TOMCAT_GROUP="tomcat"
readonly APP_BASE="/opt/tomcat"
readonly JAVA_HOME="$${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk}"

echo "=== Iniciando configuración de Tomcat v$${TOMCAT_VERSION} ==="
echo "Fecha: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
echo "Usuario: $(whoami)"
echo "JAVA_HOME: $${JAVA_HOME}"

# Verificar prerequisites
echo "[1/8] Verificando prerequisites del sistema..."
if ! command -v java &> /dev/null; then
    echo "ERROR: Java no encontrado. Instale OpenJDK 11 o superior."
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n1 | cut -d'"' -f2 | cut -d'.' -f1)
if [ "$${JAVA_VERSION}" -lt 11 ]; then
    echo "ERROR: Se requiere Java 11 o superior. Versión actual: $${JAVA_VERSION}"
    exit 1
fi
echo "Java version $${JAVA_VERSION} verificada correctamente."

# Crear usuario y grupo de Tomcat
echo "[2/8] Creando usuario y grupo del sistema..."
if ! getent group "$${TOMCAT_GROUP}" > /dev/null 2>&1; then
    groupadd --system "$${TOMCAT_GROUP}"
    echo "Grupo '$${TOMCAT_GROUP}' creado."
fi

if ! getent passwd "$${TOMCAT_USER}" > /dev/null 2>&1; then
    useradd --system --gid "$${TOMCAT_GROUP}" --home-dir "$${APP_BASE}" --shell /bin/false "$${TOMCAT_USER}"
    echo "Usuario '$${TOMCAT_USER}' creado."
fi

# Crear estructura de directorios
echo "[3/8] Creando estructura de directorios..."
mkdir -p "$${APP_BASE}/"
mkdir -p "$${APP_BASE}/conf"
mkdir -p "$${APP_BASE}/logs"
mkdir -p "$${APP_BASE}/webapps"
mkdir -p "$${APP_BASE}/temp"
mkdir -p "$${APP_BASE}/work"
mkdir -p "$${APP_BASE}/lib"
mkdir -p "$${APP_BASE}/bin"

# Descargar Tomcat si no existe
if [ ! -f "$${APP_BASE}/bin/catalina.sh" ]; then
    echo "[4/8] Descargando Apache Tomcat..."
    readonly TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v$${TOMCAT_VERSION}/bin/apache-tomcat-$${TOMCAT_VERSION}.tar.gz"
    
    curl -fsSL --connect-timeout 30 --max-time 300 "$${TOMCAT_URL}" -o /tmp/tomcat.tar.gz
    
    if [ ! -s /tmp/tomcat.tar.gz ]; then
        echo "ERROR: Falló la descarga de Tomcat"
        exit 1
    fi
    
    tar -xzf /tmp/tomcat.tar.gz -C /tmp/
    cp -r /tmp/apache-tomcat-$${TOMCAT_VERSION}/* "$${APP_BASE}/"
    rm -rf /tmp/tomcat.tar.gz /tmp/apache-tomcat-$${TOMCAT_VERSION}
    echo "Tomcat extraído en $${APP_BASE}"
fi

# Configurar variables de entorno JVM
echo "[5/8] Configurando parámetros de JVM optimizados..."

cat > "$${APP_BASE}/bin/setenv.sh" << 'ENVEOF'
#!/bin/bash
# Configuración de entorno JVM para Tomcat
# Optimizado para cargas de trabajo debanca digital
# Tuning de heap, garbage collection y rendimiento

# Configuración de Heap Size
# Basado en memoria disponible del sistema: 2GB para JVM de los 4GB totales
HEAP_SIZE="2048m"
MIN_HEAP="1024m"
MAX_HEAP="2048m"

# Parámetros de Garbage Collection
# G1GC para latencia reducida en aplicaciones web
GC_LOG_ENABLED="-Xlog:gc*:file=$${CATALINA_HOME}/logs/gc.log:time,uptime,level,tags:filecount=10,filesize=10m"
GC_TUNING="-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:G1HeapRegionSize=16m -XX:G1ReservePercent=10"

# Configuración de memoria y rendimiento
MEMORY_OPTS="-Xms$${MIN_HEAP} -Xmx$${MAX_HEAP} -XX:NewRatio=2 -XX:SurvivorRatio=8"
PERF_OPTS="-XX:+UseStringDeduplication -XX:+OptimizeStringConcat -XX:+AlwaysPreTouch"

# Configuración de threads y conexiones
THREAD_OPTS="-XX:NativeMemoryTracking=summary -XX:+UseLargePages -XX:+UseTLAB"

# Seguridad y auditoría
SECURITY_OPTS="-Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true"

# JMX para monitoreo
JMX_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9090 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=true"

# Ensamblar opciones de JVM
export CATALINA_OPTS="$${HEAP_SIZE} $${GC_LOG_ENABLED} $${GC_TUNING} $${MEMORY_OPTS} $${PERF_OPTS} $${THREAD_OPTS} $${SECURITY_OPTS} $${JMX_OPTS}"
export JAVA_OPTS="-server $${CATALINA_OPTS}"
export JAVA_HOME="$${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk}"

# Configuración de pooling de conexiones HTTP
# Maximizar throughput con conexiones persistentes
export CATALINA_OPTS="$${CATALINA_OPTS} -Dhttp.maxConnections=10000 -Dhttp.maxKeepAliveRequests=100"

echo "[CONFIG] JVM Heap: $${MIN_HEAP} - $${MAX_HEAP}"
echo "[CONFIG] GC: G1GC con MaxGCPauseMillis=200"
echo "[CONFIG] JMX enabled en puerto 9090"
ENVEOF

chmod +x "$${APP_BASE}/bin/setenv.sh"
echo "Archivo setenv.sh configurado con parámetros de JVM optimizados."

# Configurar server.xml con pooling de conexiones y connectors optimizados
echo "[6/8] Configurando server.xml con pooling de conexiones..."

cat > "$${APP_BASE}/conf/server.xml" << 'SERVEREOF'
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <GlobalNamingResources>
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <Service name="Catalina">
    <!-- Connector NIO optimizado para alto rendimiento -->
    <Connector port="8080" protocol="org.apache.coyote.http11.Http11NioProtocol"
               maxThreads="400" minSpareThreads="50" 
               acceptCount="200" connectionTimeout="20000"
               enableLookups="false" maxConnections="10000"
               acceptorThreadCount="4" pollerThreadCount="4"
               compression="on" compressionMinSize="2048"
               noCompressionUserAgents="gozilla,traviata"
               compressibleMimeType="text/html,text/xml,text/plain,text/css,text/javascript,application/javascript,application/json"
               URIEncoding="UTF-8" 
               connectionLinger="-1"
               socketBuffer="9000"
               maxKeepAliveRequests="100"
               keepAliveTimeout="5000"
               redirectPort="8443" />

    <!-- Connector AJP para integración con Apache/Nginx -->
    <Connector protocol="AJP/1.3"
               address="127.0.0.1"
               port="8009"
               redirectPort="8443"
               maxThreads="400"
               connectionTimeout="600000"
               maxParameterCount="10000"
               packetSize="65536" />

    <Engine name="Catalina" defaultHost="localhost">
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b %D %a" />
      </Host>
    </Engine>
  </Service>
</Server>
SERVEREOF

echo "server.xml configurado con pooling de conexiones y connectors optimizados."

# Configurar contexto de aplicación con pooling de datasource
echo "[7/8] Configurando contexto y datasource..."

cat > "$${APP_BASE}/conf/context.xml" << 'CONTEXTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context reloadable="true" swallowReport="true">
    <!-- Configuración de pooling de conexiones de base de datos -->
    <Resource name="jdbc/BankingDB"
              auth="Container"
              type="javax.sql.DataSource"
              factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
              driverClassName="org.postgresql.Driver"
              url="jdbc:postgresql://$${DB_HOST:-localhost}:$${DB_PORT:-5432}/$${DB_NAME:-banking}"
              username="$${DB_USER:-tomcat}"
              password="$${DB_PASSWORD:-changeme}"
              maxActive="100"
              maxIdle="30"
              maxWait="10000"
              initialSize="10"
              validationQuery="SELECT 1"
              validationInterval="30000"
              testOnBorrow="true"
              testWhileIdle="true"
              testOnReturn="false"
              timeBetweenEvictionRunsMillis="30000"
              minEvictableIdleTimeMillis="60000"
              removeAbandoned="true"
              removeAbandonedTimeout="60"
              logAbandoned="true"
              abandonWhenPercentageFull="50"
              maxAge="3600000"
              suspectTimeout="30"
              fairQueue="true"
              jmxEnabled="true"
              jdbcInterceptors="org.apache.tomcat.jdbc.pool.interceptor.ConnectionState;org.apache.tomcat.jdbc.pool.interceptor.StatementFinalizer"
              />
    
    <!-- Configuración de sesión distribuida -->
    <Manager pathname="" />
</Context>
CONTEXTEOF

echo "context.xml configurado con pooling de conexiones."

# Configurar seguridad y permisos
echo "[8/8] Aplicando configuraciones de seguridad..."

# Establecer permisos apropiados
chown -R "$${TOMCAT_USER}:$${TOMCAT_GROUP}" "$${APP_BASE}"
chmod -R u=rwX,g=rX,o=rX "$${APP_BASE}"
chmod u+x "$${APP_BASE}/bin/*.sh"

# Crear archivo de políticas de seguridad
cat > "$${APP_BASE}/conf/catalina.policy" << 'POLICYEOF'
// Política de seguridad para Tomcat
// Configurada para aplicación de banca digital

grant {
    // Permisos del código de Tomcat
    permission java.security.AllPermission;
};

// Restricciones específicas para aplicaciones web
grant codeBase "file:$${catalina.base}/webapps/-" {
    permission java.net.SocketPermission "localhost" "connect,resolve";
    permission java.net.SocketPermission "*.amazonaws.com" "connect,resolve";
    permission java.net.SocketPermission "*.internal" "connect,resolve";
    permission java.io.FilePermission "$${catalina.base}/logs/-" "read,write";
    permission java.io.FilePermission "$${catalina.base}/temp/-" "read,write,delete";
};
POLICYEOF

# Habilitar SSL/TLS configuración básica
cat > "$${APP_BASE}/conf/web.xml" << 'WEBXMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="http://xmlns.jcp.org/xml/ns/javaee"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://xmlns.jcp.org/xml/ns/javaee
                             http://xmlns.jcp.org/xml/ns/javaee/web-app_4_0.xsd"
         version="4.0">

    <display-name>Banking Application</display-name>
    
    <session-config>
        <session-timeout>30</session-timeout>
        <cookie-config>
            <http-only>true</http-only>
            <secure>false</secure>
        </cookie-config>
        <tracking-mode>COOKIE</tracking-mode>
    </session-config>

    <security-constraint>
        <web-resource-collection>
            <web-resource-name>Protected Area</web-resource-name>
            <url-pattern>/*</url-pattern>
        </web-resource-collection>
        <user-data-constraint>
            <transport-guarantee>NONE</transport-guarantee>
        </user-data-constraint>
    </security-constraint>

    <error-page>
        <error-code>404</error-code>
        <location>/error/404.html</location>
    </error-page>
    <error-page>
        <error-code>500</error-code>
        <location>/error/500.html</location>
    </error-page>
</web-app>
WEBXMLEOF

echo "Configuraciones de seguridad aplicadas."

# Verificar instalación
echo ""
echo "=== Verificando instalación de Tomcat ==="
if [ -f "$${APP_BASE}/bin/catalina.sh" ]; then
    echo "✓ Catalina.sh encontrado"
fi

if [ -f "$${APP_BASE}/bin/setenv.sh" ]; then
    echo "✓ setenv.sh configurado"
fi

if [ -f "$${APP_BASE}/conf/server.xml" ]; then
    echo "✓ server.xml configurado"
fi

echo ""
echo "=== Configuración de Tomcat completada ==="
echo "Directorio base: $${APP_BASE}"
echo "Usuario: $${TOMCAT_USER}"
echo "Puerto HTTP: 8080"
echo "Puerto AJP: 8009"
echo "Puerto shutdown: 8005"
echo ""
echo "Para iniciar Tomcat: sudo su - $${TOMCAT_USER} -c '$${APP_BASE}/bin/startup.sh'"
echo "Para detener Tomcat: sudo su - $${TOMCAT_USER} -c '$${APP_BASE}/bin/shutdown.sh'"
echo ""
echo "Logs disponibles en: $${APP_BASE}/logs/"