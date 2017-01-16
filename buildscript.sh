#!/usr/bin/env bash

# Эти переменные среды желательно объявить в системе. Но можно и тут, если лень
# JAVA_HOME =
# ANDROID_HOME =

# ======= Создаем вспомогательные переменные директории =======
# Скрипт должен находиться в корне проекта, записываем в переменную среды как директорию корневого проекта
ROOT_PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";

# Создаем директорию, если ее нет.
mkdir -p ${ROOT_PROJECT_DIR}/app/build

# ======= Создаем ключ для подписи apk =======
echo "=== (Re)Making keystore..."
rm -rf "${ROOT_PROJECT_DIR}/withoutGradle.keystore"
${JAVA_HOME}/bin/keytool \
        -genkeypair \
        -validity 10000 \
        -dname "CN=ru.altarix.example,
                OU=ALTARIX_TRAINING,
                O=Altarix,
                L=Samara,
                S=Samara,
                C=RU" \
        -keystore "${ROOT_PROJECT_DIR}/withoutGradle.keystore" \
        -storepass password \
        -keypass password \
        -alias withoutGradleKey \
        -keyalg RSA

# ======= Создаем R.java =======
echo "=== Creating R.java..."
mkdir -p ${ROOT_PROJECT_DIR}/app/build/generated_/source/r/release
${ANDROID_HOME}/build-tools/25.0.1/aapt \
        package \
        -f \
        -m \
        -S ${ROOT_PROJECT_DIR}/app/src/main/res \
        -J ${ROOT_PROJECT_DIR}/app/build/generated_/source/r/release \
        -M ${ROOT_PROJECT_DIR}/app/src/main/AndroidManifest.xml \
        -I ${ANDROID_HOME}/platforms/android-25/android.jar

# ======= Компилируем .class файлы =======
echo "=== Compiling with javac..."
CLASSES_DIR="${ROOT_PROJECT_DIR}/app/build/intermediates_/classes/release"
mkdir -p ${CLASSES_DIR}
${JAVA_HOME}/bin/javac \
        -source 1.7 \
        -target 1.7 \
        -d ${CLASSES_DIR} \
        -g \
        -encoding UTF-8 \
        -bootclasspath /home/amak/Android/Sdk/platforms/android-25/android.jar \
        -sourcepath ${ROOT_PROJECT_DIR}/app/src/main/java \
        -classpath ${CLASSES_DIR} \
            ${ROOT_PROJECT_DIR}/app/build/generated_/source/r/release/ru/altarix/training/withoutgradle/R.java \
            ${ROOT_PROJECT_DIR}/app/src/main/java/ru/altarix/training/withoutgradle/MainActivity.java \
        -XDuseUnsharedTable=true

# ======= Компилируем .dex файл =======
echo "=== Creating DEX..."
mkdir -p ${ROOT_PROJECT_DIR}/app/build/intermediates_/dex/release
${ANDROID_HOME}/build-tools/25.0.1/dx \
        --dex \
        --output=${ROOT_PROJECT_DIR}/app/build/intermediates_/dex/release/classes.dex \
        ${CLASSES_DIR} \

# ======= Собираем apk =======
echo "=== Producing APK..."
mkdir -p ${ROOT_PROJECT_DIR}/app/build/intermediates_/apk
${ANDROID_HOME}/build-tools/25.0.1/aapt \
        package \
        -f \
        --auto-add-overlay \
        --min-sdk-version 9 \
        --target-sdk-version 25 \
        --version-code 1 \
        --version-name 1.0 \
        -S ${ROOT_PROJECT_DIR}/app/src/main/res \
        -M ${ROOT_PROJECT_DIR}/app/src/main/AndroidManifest.xml \
        -I ${ANDROID_HOME}/platforms/android-25/android.jar \
        -F ${ROOT_PROJECT_DIR}/app/build/intermediates_/apk/withoutGradle.unsigned.apk \
        ${ROOT_PROJECT_DIR}/app/build/intermediates_/dex/release

# ======= Подписываем apk =======
echo "=== Signing APK..."
${JAVA_HOME}/bin/jarsigner \
        -keystore "${ROOT_PROJECT_DIR}/withoutGradle.keystore" \
        -storepass password \
        -keypass password \
        -signedjar ${ROOT_PROJECT_DIR}/app/build/intermediates_/apk/withoutGradle.signed.apk \
        ${ROOT_PROJECT_DIR}/app/build/intermediates_/apk/withoutGradle.unsigned.apk \
        withoutGradleKey

# ======= Выравниваем apk =======
echo "=== ZipAligning APK..."
OUTPUT_APK_DIR="${ROOT_PROJECT_DIR}/app/build/outputs_/apk"
mkdir -p ${ROOT_PROJECT_DIR}/app/build/outputs_/apk
${ANDROID_HOME}/build-tools/25.0.1/zipalign \
        -f \
        4 \
        ${ROOT_PROJECT_DIR}/app/build/intermediates_/apk/withoutGradle.signed.apk \
        ${ROOT_PROJECT_DIR}/app/build/outputs_/apk/withoutGradle.apk

# ======= Устанавливаем приложение =======
echo "=== Installing app"
${ANDROID_HOME}/platform-tools/adb \
        -d \
        install -r ${ROOT_PROJECT_DIR}/app/build/outputs_/apk/withoutGradle.apk

# ======= Запускаем приложение =======
echo "=== Starting app"
${ANDROID_HOME}/platform-tools/adb \
        shell \
        am start ru.altarix.training.withoutgradle/.MainActivity
