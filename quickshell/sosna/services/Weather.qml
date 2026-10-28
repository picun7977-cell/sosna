pragma Singleton

import QtQuick
import Quickshell

// Погода в городе из настроек (по умолчанию Москва) с open-meteo.com без ключа, раз в 15 минут
Singleton {
    id: root

    readonly property string city: Config.o.city
    readonly property real lat: Config.o.lat
    readonly property real lon: Config.o.lon
    onLatChanged: if (ready) refresh()

    property bool ready: false
    property int temp: 0
    property int code: 0
    property bool isDay: true
    property int max: 0
    property int min: 0
    property var hours: []          // [{ h: "23", temp, code }]
    readonly property string desc: describe(code)
    readonly property string icon: iconFor(code, isDay)
    // Что рисовать на обоях
    readonly property string fx: {
        if ([71, 73, 75, 77, 85, 86].includes(code))
            return "snow";
        if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99].includes(code))
            return "rain";
        return "none";
    }

    function describe(c: int): string {
        if (c === 0) return "Ясно";
        if (c <= 2) return "Переменная облачность";
        if (c === 3) return "Пасмурно";
        if (c === 45 || c === 48) return "Туман";
        if (c >= 51 && c <= 57) return "Морось";
        if (c >= 61 && c <= 67) return "Дождь";
        if (c >= 71 && c <= 77) return "Снег";
        if (c >= 80 && c <= 82) return "Ливень";
        if (c === 85 || c === 86) return "Снегопад";
        if (c >= 95) return "Гроза";
        return "—";
    }

    function iconFor(c: int, day: bool): string {
        if (c === 0) return day ? "clear_day" : "clear_night";
        if (c <= 2) return day ? "partly_cloudy_day" : "partly_cloudy_night";
        if (c === 3) return "cloud";
        if (c === 45 || c === 48) return "foggy";
        if (c >= 51 && c <= 67 || c >= 80 && c <= 82) return "rainy";
        if (c >= 71 && c <= 77 || c === 85 || c === 86) return "weather_snowy";
        if (c >= 95) return "thunderstorm";
        return "cloud";
    }

    function signed(t: int): string {
        return (t > 0 ? "+" : t < 0 ? "−" : "") + Math.abs(t) + "°";
    }

    function refresh(): void {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon
            + "&current=temperature_2m,weather_code,is_day&hourly=temperature_2m,weather_code"
            + "&daily=temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=2";
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            try {
                const d = JSON.parse(xhr.responseText);
                root.temp = Math.round(d.current.temperature_2m);
                root.code = d.current.weather_code;
                root.isDay = d.current.is_day === 1;
                root.max = Math.round(d.daily.temperature_2m_max[0]);
                root.min = Math.round(d.daily.temperature_2m_min[0]);
                const now = d.current.time.slice(0, 13);
                const start = d.hourly.time.findIndex(t => t.slice(0, 13) === now);
                const hrs = [];
                for (let i = start + 1; i < start + 6 && i < d.hourly.time.length; i++)
                    hrs.push({ h: d.hourly.time[i].slice(11, 13), temp: Math.round(d.hourly.temperature_2m[i]), code: d.hourly.weather_code[i] });
                root.hours = hrs;
                root.ready = true;
            } catch (e) {
                // Сеть ещё не поднялась (или VPN переподключается) — пробуем снова через полминуты
                retry.restart();
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    Timer {
        id: retry
        interval: 30000
        onTriggered: root.refresh()
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 15 * 60 * 1000
        onTriggered: root.refresh()
    }
}
