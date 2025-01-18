#!/bin/bash

# Скрипт для получения и расшифровки METAR информации для аэропорта Пулково (ULLI)
# Автор: [Nikita Vlasov]

set -euo pipefail

# URL для получения HTML с METAR
METAR_URL="https://www.metartaf.pro/ULLI"

# Интервал обновления (в минутах) по умолчанию
DEFAULT_UPDATE_INTERVAL=15

# Функция для получения HTML и извлечения METAR строки
get_metar() {
  local html_data metar_data
  html_data=$(curl -s "$METAR_URL")
  # Извлекаем только строку METAR
  metar_data=$(echo "$html_data" | grep -oP '(?<=<dd class="mt-1 text-md font-semibold tracking-tight text-gray-900">)[A-Z0-9/ ]+(?=</dd>)')
  if [[ -z "$metar_data" ]]; then
    echo "Ошибка: Не удалось извлечь строку METAR." >&2
    exit 1
  fi
  echo "$metar_data"
}

# Функция для расшифровки METAR данных
decode_metar() {
  local metar="$1"
  echo "Исходные данные: $metar"

  # Разбиваем строку METAR на части
  local parts=($metar)
  local airport="${parts[0]}"
  local time="${parts[1]}"
  local wind="${parts[2]}"
  local visibility="${parts[3]}"
  local weather="${parts[4]}"
  local temp_and_dew="${parts[5]}"
  local pressure="${parts[6]}"
  local runway_condition="${parts[7]:-}"
  local nosig="${parts[8]:-}"

  # Расшифровка
  echo "Расшифровка:"
  echo "1) Аэропорт: $airport (Пулково, ULLI)"
  echo "2) Время: ${time:0:2}:${time:2:2} UTC (${time:4:2} сек)"
  echo "3) Ветер: $(decode_wind "$wind")"
  echo "4) Видимость: $(decode_visibility "$visibility")"
  echo "5) Погода: $(decode_weather "$weather")"
  echo "6) Температура и точка росы: $(decode_temp "$temp_and_dew")"
  echo "7) Давление: $(decode_pressure "$pressure")"
  [[ -n "$runway_condition" ]] && echo "8) Условия на ВПП: $runway_condition"
  [[ -n "$nosig" ]] && echo "9) Прогноз изменений: $nosig"
}

# Функция для расшифровки ветра
decode_wind() {
  local wind="$1"
  local direction="${wind:0:3}"
  local speed="${wind:3:2}"
  echo "Направление: $direction°, Скорость: $speed м/с"
}

# Функция для расшифровки видимости
decode_visibility() {
  local visibility="$1"
  if [[ "$visibility" == "9999" || "$visibility" == "CAVOK" ]]; then
    echo "Более 10 км"
  else
    echo "$visibility м"
  fi
}

# Функция для расшифровки погоды
decode_weather() {
  local weather="$1"
  if [[ "$weather" == "CAVOK" ]]; then
    echo "Ясно, видимость и условия полёта хорошие"
  else
    echo "Неизвестное состояние: $weather"
  fi
}

# Функция для расшифровки температуры и точки росы
decode_temp() {
  local temp_and_dew="$1"
  local temp="${temp_and_dew%/*}"
  local dew="${temp_and_dew#*/}"
  echo "Температура: $temp°C, Точка росы: $dew°C"
}

# Функция для расшифровки давления
decode_pressure() {
  local pressure="$1"
  local qnh="${pressure:1}"
  echo "$qnh гПа (нормальное давление: 1013 гПа)"
}

# Функция для автоматического обновления METAR
auto_update() {
  local interval="$1"
  echo "Автоматическое обновление каждые $interval минут"
  while true; do
    local metar
    metar=$(get_metar)
    decode_metar "$metar"
    echo "---------------------------------------"
    sleep $((interval * 60))
  done
}

# Основной код
main() {
  local update_interval=0

  # Обработка аргументов командной строки
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --upd)
        update_interval=$(($2 / 60))  # Интерпретируем переданный аргумент как секунды и преобразуем в минуты
        shift 2
        ;;
      *)
        echo "Неизвестный аргумент: $1" >&2
        exit 1
        ;;
    esac
  done

  if [[ "$update_interval" -gt 0 ]]; then
    auto_update "$update_interval"
  else
    local metar
    metar=$(get_metar)
    decode_metar "$metar"
  fi
}

main "$@"
