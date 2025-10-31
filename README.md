# DIGITALVORTX WaterWall - HalfDuplex Tunnel Manager

یک اسکریپت مدیریتی کامل برای نصب و پیکربندی WaterWall با پروتکل HalfDuplex

## ✨ ویژگی‌ها

- 🔍 **تشخیص خودکار معماری**: به‌صورت خودکار معماری سیستم (ARM64 یا AMD64) را تشخیص می‌دهد
- 📥 **دانلود و نصب خودکار**: نسخه مناسب WaterWall v1.40 را دانلود و نصب می‌کند
- 📁 **نصب در مسیر متمرکز**: همه فایل‌ها در `/waterwall` قرار می‌گیرند
- 🔧 **پیکربندی ساده**: منوی تعاملی برای پیکربندی ایران یا خارج
- 🔌 **پشتیبانی از پورت‌های متعدد**: تک پورت، چند پورت (comma-separated) و بازه پورت (range)
- 🎨 **رابط کاربری زیبا**: منوی رنگی و جذاب
- 📊 **نمایش وضعیت**: بررسی وضعیت نصب و اجرای Tunnel
- 🚀 **مدیریت ساده**: شروع و توقف آسان Tunnel

## 📋 پیش‌نیازها

- سیستم عامل Linux (Debian/Ubuntu/CentOS)
- دسترسی root یا sudo
- اتصال به اینترنت برای دانلود

## 🚀 نصب و اجرا

```bash
# دانلود اسکریپت
wget https://raw.githubusercontent.com/DIGITALVORTEX-TEAM/DIGITALVORTEX-WaterWall/main/DIGITALVORTX-waterwall.sh

# یا با curl
curl -O https://raw.githubusercontent.com/DIGITALVORTEX-TEAM/DIGITALVORTEX-WaterWall/main/DIGITALVORTX-waterwall.sh

# یا دانلود و اجرای مستقیم
bash <(curl -Ls https://raw.githubusercontent.com/DIGITALVORTEX-TEAM/DIGITALVORTEX-WaterWall/main/DIGITALVORTX-waterwall.sh)

# یا clone کردن repository
git clone https://github.com/DIGITALVORTEX-TEAM/DIGITALVORTEX-WaterWall.git
cd DIGITALVORTEX-WaterWall
chmod +x DIGITALVORTX-waterwall.sh
sudo ./DIGITALVORTX-waterwall.sh
```

## 📖 نحوه استفاده

### 1. نصب Core

- از منوی اصلی گزینه `1 - INSTALL CORE` را انتخاب کنید
- اسکریپت به‌صورت خودکار معماری سیستم را تشخیص می‌دهد
- نسخه مناسب WaterWall دانلود و نصب می‌شود
- همه فایل‌ها در `/waterwall` قرار می‌گیرند

### 2. پیکربندی Tunnel

- گزینه `2 - Config HalfDuplex Tunnel` را انتخاب کنید
- نوع سرور را انتخاب کنید:
  - **IRAN Server**: استفاده از HalfDuplexClient
  - **Kharej/Foreign Server**: استفاده از HalfDuplexServer

### 3. وارد کردن اطلاعات

#### برای سرور ایران:
- آدرس Listener (پیش‌فرض: 0.0.0.0)
- پورت‌های Listener (مثال: `8447`, `8447,8448,8449` یا `8447-8450`)
- IP سرور خارج
- پورت‌های Connector به سرور خارج

#### برای سرور خارج:
- آدرس Listener (پیش‌فرض: 0.0.0.0)
- پورت‌های Listener (مثال: `8443`, `8443,8444,8445` یا `8443-8446`)
- IP سرور ایران
- پورت‌های Connector به سرور ایران

### 4. شروع Tunnel

- گزینه `4 - Start Tunnel` را انتخاب کنید
- Tunnel در یک screen session اجرا می‌شود
- برای مشاهده لاگ‌ها: `screen -r WaterWall`

## 📝 مثال پیکربندی

### سرور ایران:
```json
{
  "name": "iran_server_config",
  "nodes": [
    {
      "name": "iran_multi_port_listener",
      "type": "TcpListener",
      "settings": {
        "address": "0.0.0.0",
        "port": [8447, 8448, 8449, 8450],
        "nodelay": true,
        "multiport-backend": "iptables"
      },
      "next": "halfduplex_client"
    },
    {
      "name": "halfduplex_client",
      "type": "HalfDuplexClient",
      "settings": {},
      "next": "foreign_connector"
    },
    {
      "name": "foreign_connector",
      "type": "TcpConnector",
      "settings": {
        "address": "FOREIGN_SERVER_IP",
        "port": [8443, 8444, 8445, 8446],
        "nodelay": true,
        "fastopen": false,
        "domain-strategy": "ipv4"
      },
      "next": null
    }
  ]
}
```

### سرور خارج:
```json
{
  "name": "foreign_server_config",
  "nodes": [
    {
      "name": "foreign_multi_port_listener",
      "type": "TcpListener",
      "settings": {
        "address": "0.0.0.0",
        "port": [8443, 8444, 8445, 8446],
        "nodelay": true,
        "multiport-backend": "iptables"
      },
      "next": "halfduplex_server"
    },
    {
      "name": "halfduplex_server",
      "type": "HalfDuplexServer",
      "settings": {},
      "next": "iran_connector"
    },
    {
      "name": "iran_connector",
      "type": "TcpConnector",
      "settings": {
        "address": "IRAN_SERVER_IP",
        "port": [8447, 8448, 8449, 8450],
        "nodelay": true,
        "fastopen": false,
        "domain-strategy": "ipv4"
      },
      "next": null
    }
  ]
}
```

## 📂 ساختار پوشه

```
/waterwall/
├── Waterwall          # فایل اجرایی اصلی
├── core.json          # تنظیمات هسته
├── dev-ir.json        # تنظیمات Tunnel
├── log/              # پوشه لاگ‌ها
│   ├── core.log
│   ├── network.log
│   └── dns.log
└── libs/             # کتابخانه‌های مورد نیاز
```

## 🛠️ دستورات مفید

```bash
# مشاهده لاگ‌های Tunnel
screen -r WaterWall

# خروج از screen (بدون توقف Tunnel)
Ctrl+A سپس D

# توقف Tunnel
screen -X -S WaterWall quit

# مشاهده وضعیت
sudo ./DIGITALVORTX-waterwall.sh
# سپس گزینه 3 - Status Tunnel

# مشاهده فایل کانفیگ
cat /waterwall/dev-ir.json | jq '.'

# ویرایش دستی کانفیگ
sudo nano /waterwall/dev-ir.json
```

## 🔗 لینک‌های مفید

- 📦 [Repository GitHub](https://github.com/DIGITALVORTEX-TEAM/DIGITALVORTEX-WaterWall)
- 📥 [دانلود مستقیم اسکریپت](https://raw.githubusercontent.com/DIGITALVORTEX-TEAM/DIGITALVORTEX-WaterWall/main/DIGITALVORTX-waterwall.sh)
- 📚 [مستندات WaterWall](https://radkesvat.github.io/WaterWall-Docs/)
- 📖 [Installation Guide](https://radkesvat.github.io/WaterWall-Docs/docs/getting-started/installation)
- 🔌 [HalfDuplex Client](https://radkesvat.github.io/WaterWall-Docs/docs/noderefs/halfduplex-client)
- 🔌 [HalfDuplex Server](https://radkesvat.github.io/WaterWall-Docs/docs/noderefs/halfduplex-server)

## 📌 نکات مهم

- ⚠️ برای نصب و اجرا به دسترسی root نیاز دارید
- ⚠️ قبل از شروع، مطمئن شوید که پورت‌های مورد نظر باز هستند
- ⚠️ تنظیمات iptables به‌صورت خودکار در کانفیگ اعمال می‌شود (multiport-backend)
- ⚠️ IP سرور مقابل را با دقت وارد کنید

## 🐛 عیب‌یابی

### مشکل: فایل دانلود نمی‌شود
```bash
# بررسی اتصال به اینترنت
ping github.com

# دانلود دستی
wget https://github.com/radkesvat/WaterWall/releases/download/v1.40/Waterwall-linux-gcc-x64.zip
```

### مشکل: Tunnel شروع نمی‌شود
```bash
# بررسی وجود فایل‌ها
ls -la /waterwall/

# بررسی لاگ‌ها
tail -f /waterwall/log/core.log
tail -f /waterwall/log/network.log
```

### مشکل: پورت در حال استفاده است
```bash
# بررسی پورت‌های استفاده شده
netstat -tulpn | grep LISTEN
# یا
ss -tulpn | grep LISTEN
```

## 📄 مجوز

این پروژه تحت مجوز MIT منتشر شده است.

## 👨‍💻 توسعه‌دهنده

**DIGITALVORTX**

## 🙏 تشکر

از [radkesvat](https://github.com/radkesvat) برای توسعه WaterWall تشکر می‌کنیم.

---

⭐ اگر این پروژه برای شما مفید بود، لطفاً آن را ستاره دهید!

