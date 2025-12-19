# Changelog

All notable changes to **TxMTC** (Telegram x MikroTik Tunnel Controller Sub-Agent) will be documented in this file.

*Crafted with love & frustration by P̷h̷e̷n̷i̷x̷*

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-12-20

### 🎨 Complete Rebrand - TxMTC by P̷h̷e̷n̷i̷x̷

The project has been rebranded from "MikroTik Telegram Bot" to **TxMTC** (Telegram x MikroTik Tunnel Controller Sub-Agent).

### Added
- ASCII art PHENIX banner in installation output
- P̷h̷e̷n̷i̷x̷ creator branding throughout
- Friendly-minimal bot reply style (`⚡ TxMTC` prefix)
- Roadmap section in README.md
- Future enhancements tracking (auto-updater, WebApp, hotspot monitoring)

### Changed
- All script headers updated with new TxMTC branding
- Bot reply subjects now use `⚡ TxMTC | [Type]` format
- Help text redesigned for minimal, scannable output
- README.md completely rewritten with new branding
- QUICKSTART.md updated with TxMTC references
- Installation banner shows PHENIX ASCII art

### Improved
- Cleaner, more concise bot responses
- Better organization of help command output
- Unified branding across all 11 scripts
- Consistent header format with GitHub link

---

## [1.0.0] - 2024-12-17

### 🎉 Initial Release - Production-Ready

This release includes everything needed for enterprise-grade MikroTik router management via Telegram.

### Core Bot Features
- Complete Telegram Bot API integration with polling
- Interactive command execution with syntax validation
- Device activation system (`! identity` or `! @group`)
- Multi-device group management support
- Trusted user authentication and whitelisting
- Reply-to-message contextual command execution
- Command timeout handling (20s default)
- Output formatting with Telegram message limit handling
- Queue-based notification system with retry logic
- Custom command alias support

#### System Monitoring
- **CPU Monitoring**: 5-point moving average, 75% threshold (configurable)
- **RAM Monitoring**: Usage tracking, 80% threshold (configurable)
- **Disk Monitoring**: Space tracking, 90% threshold (configurable)
- **Temperature Monitoring**: Sensor reading with alerts (60°C default)
- **Voltage Monitoring**: Power supply monitoring with range alerts
- **Interface Monitoring**: Status tracking, error detection, traffic analysis
- **System Events**: Restart detection and uptime tracking
- **Recovery Notifications**: Automatic alerts when issues resolve
- **Trend Analysis**: Moving averages prevent false alerts

#### Wireless Monitoring ⭐ NEW
- WiFi interface status monitoring
- Connected client tracking with count alerts
- Signal strength monitoring (-80 dBm threshold)
- Per-client MAC address and signal level tracking
- Weak signal automatic detection
- `/wireless` command for comprehensive status
- `/wireless-scan` command for site surveys

#### Backup Features
- Automated scheduled backups
- Manual on-demand backup via `/backup now`
- Backup file rotation with configurable retention
- MikroTik Cloud backup support
- Configuration export alongside binary backups
- Backup verification and size validation
- Telegram notifications for backup completion

#### User-Friendly Commands
- `/help` - Display available commands with descriptions
- `/status` - Comprehensive system overview (CPU, RAM, disk, uptime, interfaces)
- `/interfaces` - Detailed interface statistics with status indicators
- `/dhcp` - DHCP lease list with hostnames and MAC addresses
- `/logs [filter]` - View recent system logs with optional filtering
- `/traffic [interface]` - Interface traffic statistics and packet counts
- `/update [check|install]` - RouterOS update management
- `/backup [now|list]` - Backup creation and management
- `/reboot [confirm]` - Safe reboot requiring explicit confirmation
- `/wireless` - Wireless status and client information ⭐ NEW
- `/wireless-scan [interface]` - Network scanning ⭐ NEW
- `?` - Quick bot status check
- `! identity` - Activate specific device
- `! @group` - Activate device group
- `!` - Deactivate all devices

#### Documentation (450+ pages)
- **README.md**: Comprehensive project overview with feature highlights
- **QUICKSTART.md**: 15-minute setup guide for beginners ⭐ NEW
- **FAQ.md**: 150+ frequently asked questions with detailed answers ⭐ NEW
- **PERFORMANCE.md**: Complete optimization guide with benchmarks ⭐ NEW
- **setup/telegram-setup.md**: BotFather walkthrough with screenshots
- **setup/installation.md**: Step-by-step RouterOS installation (multiple methods)
- **setup/security-hardening.md**: Enterprise security practices ⭐ NEW
- **examples/usage-examples.md**: 50+ real-world usage scenarios
- **CONTRIBUTING.md**: Community contribution guidelines ⭐ NEW
- **CHANGELOG.md**: Version history and roadmap (this file)
- **PROJECT-SUMMARY.md**: Complete project overview ⭐ NEW
- **ENHANCEMENTS-SUMMARY.md**: Beyond-plan features ⭐ NEW
- **FILE-INDEX.md**: Complete file index and navigation ⭐ NEW

#### Configuration
- Fully configurable thresholds for all monitors
- Custom command aliases support
- Multi-device group management
- Flexible notification settings
- Backup schedule and retention configuration
- Rate limiting and security controls

#### Automated Tools ⭐ NEW
- **deploy.rsc**: One-command automated deployment with verification
- **verify-installation.rsc**: 10-point installation validation
- **troubleshoot.rsc**: Automated diagnostics with specific recommendations

### Security
- User ID whitelist for access control (numeric ID or username)
- Complete command execution audit logging
- Untrusted access attempt detection and notification
- Comprehensive input validation and syntax checking
- Secure credential storage in configuration
- Dangerous command confirmation requirements (configurable list)
- Optional command whitelist mode for high-security environments
- Rate limiting per user (configurable)
- HTTPS-only communication with certificate validation
- Security audit script with weekly automated reports ⭐ NEW
- Incident response procedures and playbooks ⭐ NEW
- Complete security hardening guide ⭐ NEW

### Based On
- [RouterOS Scripts](https://github.com/eworm-de/routeros-scripts) by eworm-de
- Telegram Bot API
- MikroTik RouterOS 7.15+

### Performance & Optimization
- Configurable polling intervals (15s to 120s)
- Smart random delay to prevent simultaneous polling
- Efficient memory management with cleanup routines
- Network payload optimization
- Script execution optimization with caching
- Resource usage profiling tools
- Performance benchmarks by device class
- Complete optimization guide with best practices ⭐ NEW

### Project Infrastructure
- GPL-3.0 license with proper attribution
- Comprehensive .gitignore for RouterOS projects
- Semantic versioning structure
- Professional changelog format
- Community contribution framework
- Code of conduct and guidelines

### Statistics
- **9 RouterOS Scripts**: ~3,050 lines of code
- **13 Documentation Files**: ~450 pages
- **60+ Features**: Fully documented
- **12+ Commands**: User-friendly interface
- **50+ Examples**: Real-world scenarios
- **150+ Q&As**: Comprehensive FAQ
- **3 Automation Tools**: Deployment, verification, troubleshooting

## [Unreleased]

### Planned Features (Roadmap)
- Direct backup file upload to Telegram (requires multipart/form-data support in RouterOS)
- Interactive button menus using Telegram inline keyboards
- Webhook support as alternative to polling (lower latency)
- Two-factor authentication for critical command execution
- Extended monitoring plugins system for custom metrics
- Traffic analysis with anomaly detection and reporting
- Scheduled maintenance mode with automatic notifications
- Multi-language support (i18n) for international users
- Web dashboard for visual configuration and monitoring
- Mobile app companion (iOS/Android)
- Integration with external monitoring systems (Prometheus, Grafana)
- Advanced reporting with PDF generation
- Geo-location tracking for mobile routers

### Known Issues
- Direct file upload to Telegram has limitations due to RouterOS fetch constraints
- Large command outputs may be truncated (Telegram 4096 char limit)
- Commands exceeding timeout continue in background without output
- Numeric IDs (e.g., `/ip address remove 0`) don't work across messages

## Contributing

We welcome contributions! Please see our contributing guidelines for:
- Bug reports
- Feature requests
- Code contributions
- Documentation improvements

## Support

- Documentation: See [docs folder](./setup/)
- Community: [@routeros_scripts](https://t.me/routeros_scripts) on Telegram
- Issues: [GitHub Issues](https://github.com/yourusername/mikrotik-telegram-bot/issues)

---

[1.0.0]: https://github.com/Danz17/Agents-smart-tools/releases/tag/v1.0.0

