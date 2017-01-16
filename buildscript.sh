#!/usr/bin/env bash

# Эти переменные среды желательно объявить в системе. Но можно и тут, если лень
# JAVA_HOME=
# ANDROID_HOME=

# ======= Настройки скрипта =======
COMPILE_SDK_VERSION="25"
BUILD_TOOLS_VERSION="25.0.0"
PACKAGE_NAME="ru.altarix.training.withoutgradle"

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
        -S ${APP_PROJECT_DIR}/src/main/res \
        -J ${GEN_SOURCES_DIR} \
        -M ${APP_PROJECT_DIR}/src/main/AndroidManifest.xml \
        -I ${ANDROID_HOME}/platforms/android-${COMPILE_SDK_VERSION}/android.jar

# ======= Компилируем .dex файл =======
echo "=== Creating DEX..."
DEX_DIR="${APP_BUILD_DIR}/intermediates_/dex/release"
mkdir -p ${DEX_DIR}

java -jar ${ANDROID_HOME}/build-tools/${BUILD_TOOLS_VERSION}/jack.jar \
        --classpath "${ANDROID_HOME}/platforms/android-${COMPILE_SDK_VERSION}/android.jar" \
        --output-dex ${DEX_DIR} \
        ${APP_SOURCES_DIR}/ ${GEN_SOURCES_DIR}/

# ======= Собираем apk =======
echo "=== Producing APK..."
APK_INTERMEDIATES="${APP_BUILD_DIR}/intermediates_/apk"
mkdir -p ${APK_INTERMEDIATES}

${ANDROID_HOME}/build-tools/${BUILD_TOOLS_VERSION}/aapt \
        package \
        -f \
        --auto-add-overlay \
        --min-sdk-version 9 \
        --target-sdk-version 25 \
        --version-code 1 \
        --version-name 1.0 \
        -S ${APP_PROJECT_DIR}/src/main/res \
        -M ${APP_PROJECT_DIR}/src/main/AndroidManifest.xml \
        -I ${ANDROID_HOME}/platforms/android-${COMPILE_SDK_VERSION}/android.jar \
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
