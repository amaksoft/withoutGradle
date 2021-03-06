#!/usr/bin/env bash

# Эти переменные среды желательно объявить в системе. Но можно и тут, если лень
# JAVA_HOME =
# ANDROID_HOME =

# ======= Настройки скрипта =======
COMPILE_SDK_VERSION="25"
BUILD_TOOLS_VERSION="25.0.1"
PACKAGE_NAME="ru.altarix.training.withoutgradle"

V_APP_COMPAT="25.1.0"

# Локальный maven-репозиторий, устанавливаемый с SDK
LOCAL_REPO="${ANDROID_HOME}/extras/android/m2repository"

# Библиотеки:
LIBRARIES="${LOCAL_REPO}/com/android/support/appcompat-v7/${V_APP_COMPAT}/appcompat-v7-${V_APP_COMPAT}.aar
        ${LOCAL_REPO}/com/android/support/support-v4/${V_APP_COMPAT}/support-v4-${V_APP_COMPAT}.aar
        ${LOCAL_REPO}/com/android/support/animated-vector-drawable/${V_APP_COMPAT}/animated-vector-drawable-${V_APP_COMPAT}.aar
        ${LOCAL_REPO}/com/android/support/support-annotations/${V_APP_COMPAT}/support-annotations-${V_APP_COMPAT}.jar
        ${LOCAL_REPO}/com/android/support/support-compat/${V_APP_COMPAT}/support-compat-${V_APP_COMPAT}.aar
        ${LOCAL_REPO}/com/android/support/support-core-ui/${V_APP_COMPAT}/support-core-ui-${V_APP_COMPAT}.aar
        ${LOCAL_REPO}/com/android/support/support-core-utils/${V_APP_COMPAT}/support-core-utils-${V_APP_COMPAT}.aar
        ${LOCAL_REPO}/com/android/support/support-fragment/${V_APP_COMPAT}/support-fragment-${V_APP_COMPAT}.aar
        ${LOCAL_REPO}/com/android/support/support-media-compat/${V_APP_COMPAT}/support-media-compat-${V_APP_COMPAT}.aar
        ${LOCAL_REPO}/com/android/support/support-vector-drawable/${V_APP_COMPAT}/support-vector-drawable-${V_APP_COMPAT}.aar"

# ======= Создаем вспомогательные переменные директории =======
# Скрипт должен находиться в корне проекта, записываем в переменную среды как директорию корневого проекта
ROOT_PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
# Пускай имя проекта будет такое же как и имя корневой папки
PROJECT_NAME=${ROOT_PROJECT_DIR##*/}
# Для сохранения привычной всем структуры проекта субпроект приложения будет находиться в папке /app корневого проекта
APP_PROJECT_DIR="${ROOT_PROJECT_DIR}/app"
# Привычная папка build в папке приложения для сохранения результатов сборки.
APP_BUILD_DIR="$APP_PROJECT_DIR/build"
# Создаем директорию, если ее нет.
mkdir -p ${APP_BUILD_DIR}

# ======= Распаковываем либы =======
echo "=== Preparing libs..."
for LIB in ${LIBRARIES}; do
    LIBDIR="${APP_BUILD_DIR}/intermediates_/exploded-aar/${LIB##*/}"
    EX_LIBS+="${LIBDIR} "
    mkdir -p ${LIBDIR}
    unzip -q ${LIB} -d ${LIBDIR}
    if [[ -f ${LIBDIR}/classes.jar ]]; then
        LIBS_JARS+="${LIBDIR}/classes.jar "
    fi
    if [ "$(ls -A ${LIBDIR}/res 2> /dev/null)" ]; then
        LIBS_RES_AAPT+="-S ${LIBDIR}/res "
    fi
done

# ======= Создаем ключ для подписи apk =======
echo "=== (Re)Making keystore..."
rm -rf "${ROOT_PROJECT_DIR}/${PROJECT_NAME}.keystore"
${JAVA_HOME}/bin/keytool \
        -genkeypair \
        -validity 10000 \
        -dname "CN=ru.altarix.example,
                OU=ALTARIX_TRAINING,
                O=Altarix,
                L=Samara,
                S=Samara,
                C=RU" \
        -keystore "${ROOT_PROJECT_DIR}/${PROJECT_NAME}.keystore" \
        -storepass password \
        -keypass password \
        -alias ${PROJECT_NAME}Key \
        -keyalg RSA

# ======= Создаем R.java =======
echo "=== Creating R.java..."
APP_SOURCES_DIR="${APP_PROJECT_DIR}/src/main/java"
GEN_SOURCES_DIR="${APP_BUILD_DIR}/generated_/source/r/release"
mkdir -p ${GEN_SOURCES_DIR}

${ANDROID_HOME}/build-tools/${BUILD_TOOLS_VERSION}/aapt \
        package \
        -f \
        -m \
        --auto-add-overlay \
        -S ${APP_PROJECT_DIR}/src/main/res \
        -J ${GEN_SOURCES_DIR} \
        -M ${APP_PROJECT_DIR}/src/main/AndroidManifest.xml \
        -I ${ANDROID_HOME}/platforms/android-${COMPILE_SDK_VERSION}/android.jar \
        --extra-packages android.support.v7.appcompat:android.support.v4 \
        ${LIBS_RES_AAPT}

# ======= Компилируем .class файлы =======
echo "=== Compiling with javac..."
CLASSES_DIR="${APP_BUILD_DIR}/intermediates_/classes/release"
mkdir -p ${CLASSES_DIR}

${JAVA_HOME}/bin/javac \
        -source 1.7 \
        -target 1.7 \
        -d ${CLASSES_DIR} \
        -g \
        -encoding UTF-8 \
        -bootclasspath /home/amak/Android/Sdk/platforms/android-25/android.jar \
        -sourcepath ${APP_SOURCES_DIR} \
        -classpath ${LIBS_JARS// /:} \
            ${GEN_SOURCES_DIR}/${PACKAGE_NAME//./\/}/R.java \
            ${GEN_SOURCES_DIR}/android/support/v4/R.java \
            ${GEN_SOURCES_DIR}/android/support/v7/appcompat/R.java \
            ${APP_SOURCES_DIR}/${PACKAGE_NAME//./\/}/MainActivity.java \
        -XDuseUnsharedTable=true

# ======= Компилируем .dex файл =======
echo "=== Creating DEX..."
DEX_DIR="${APP_BUILD_DIR}/intermediates_/dex/release"
mkdir -p ${DEX_DIR}

${ANDROID_HOME}/build-tools/${BUILD_TOOLS_VERSION}/dx \
        --dex \
        --output=${DEX_DIR}/classes.dex \
        ${CLASSES_DIR} \
        ${LIBS_JARS}

# ======= Собираем apk =======
echo "=== Producing APK..."
APK_INTERMEDIATES="${APP_BUILD_DIR}/intermediates_/apk"
mkdir -p ${APK_INTERMEDIATES}

${ANDROID_HOME}/build-tools/${BUILD_TOOLS_VERSION}/aapt \
        package \
        -f \
        --min-sdk-version 9 \
        --target-sdk-version 25 \
        --version-code 1 \
        --version-name 1.0 \
        --auto-add-overlay \
        -S ${APP_PROJECT_DIR}/src/main/res \
        -M ${APP_PROJECT_DIR}/src/main/AndroidManifest.xml \
        -I ${ANDROID_HOME}/platforms/android-${COMPILE_SDK_VERSION}/android.jar \
        --extra-packages android.support.v7.appcompat:android.support.v4 \
        ${LIBS_RES_AAPT} \
        -F ${APK_INTERMEDIATES}/${PROJECT_NAME}.unsigned.apk \
        ${DEX_DIR}

# ======= Подписываем apk =======
echo "=== Signing APK..."
${JAVA_HOME}/bin/jarsigner \
        -keystore "${ROOT_PROJECT_DIR}/${PROJECT_NAME}.keystore" \
        -storepass password \
        -keypass password \
        -signedjar ${APK_INTERMEDIATES}/${PROJECT_NAME}.signed.apk \
        ${APK_INTERMEDIATES}/${PROJECT_NAME}.unsigned.apk \
        ${PROJECT_NAME}Key

# ======= Выравниваем apk =======
echo "=== ZipAligning APK..."
OUTPUT_APK_DIR="${APP_BUILD_DIR}/outputs_/apk"
mkdir -p ${OUTPUT_APK_DIR}

${ANDROID_HOME}/build-tools/${BUILD_TOOLS_VERSION}/zipalign \
        -f \
        4 \
        ${APK_INTERMEDIATES}/${PROJECT_NAME}.signed.apk \
        ${OUTPUT_APK_DIR}/${PROJECT_NAME}.apk

# ======= Устанавливаем приложение =======
echo "=== Installing app"
${ANDROID_HOME}/platform-tools/adb \
        -d \
        install -r ${OUTPUT_APK_DIR}/${PROJECT_NAME}.apk

# ======= Заапускаем приложение =======
echo "=== Starting app"
${ANDROID_HOME}/platform-tools/adb \
        shell \
        am start ${PACKAGE_NAME}/.MainActivity