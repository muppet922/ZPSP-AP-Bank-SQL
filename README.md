# 🧟 ZPSP-AmmoPacks-Bank-SQL

![Zombie Plague Special](https://img.shields.io/badge/Zombie%20Plague-Special-brightgreen)
![AMXX](https://img.shields.io/badge/AMXX-1.8.2%2B-blue)
![MySQL](https://img.shields.io/badge/Database-MySQL-orange)

An AMX Mod X plugin designed to work with Zombie Plague Special mod for Counter-Strike 1.6, providing a robust ammo pack banking system.

## 🚀 Features

- 💾 Persistent ammo pack storage using MySQL database
- 🔄 Automatic saving of ammo packs on disconnect and round end
- 🛠 Admin command to give ammo packs to players
- 🤖 Bot support with fixed ammo pack amount
- 🧟‍♂️ Compatible with Zombie Plague Special events (infection, humanization)
- 🌐 Multi-language support

## 📋 Requirements

- AMX Mod X 1.8.2 or higher
- Zombie Plague Special mod
- MySQL database

## 📥 Installation

1. Compile the plugin using the AMX Mod X compiler.
2. Upload the compiled `.amxx` file to your `addons/amxmodx/plugins/` directory.
3. Add the plugin to your `plugins.ini` file:
   ```
   zpsp_banca_ammopacks.amxx
   ```

## ⚙️ Configuration

1. Create a new file named `zpsp_bank_mysql.cfg` in your `addons/amxmodx/configs/` directory.
2. Add the following lines to the file, replacing the values with your actual database information:
   ```
   zpsp_mysql_host "localhost"
   zpsp_mysql_user "your_username"
   zpsp_mysql_pass "your_password"
   zpsp_mysql_db "your_database_name"
   ```
3. Ensure that the MySQL module is loaded in your `modules.ini` file.

## 🎮 Usage

### Admin Commands

| Command | Description |
|---------|-------------|
| `amx_giveap <target> <amount>` | Give ammo packs to a player |

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues or pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

If you encounter any issues or have questions, please [open an issue](../../issues) on this repository.

---

💡 **Tip:** Remember to regularly update your AMX Mod X and Zombie Plague Special mod for the best performance and security.
