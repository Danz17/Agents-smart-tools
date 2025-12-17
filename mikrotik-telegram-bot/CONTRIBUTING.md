# Contributing to MikroTik Telegram Bot

Thank you for your interest in contributing! This project welcomes contributions from the community.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)
- [Code Contributions](#code-contributions)
- [Documentation](#documentation)
- [Testing](#testing)
- [Style Guidelines](#style-guidelines)

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Respect differing viewpoints

## How to Contribute

### Reporting Bugs

Found a bug? Help us fix it!

**Before submitting:**
1. Check if the issue already exists
2. Test on the latest version
3. Gather relevant information

**When reporting, include:**
- RouterOS version (`/system resource print`)
- Bot version (check CHANGELOG.md)
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Relevant log entries (`/log print where topics~"script"`)
- Configuration (remove sensitive data like tokens)

**Bug Report Template:**
```markdown
## Bug Description
[Clear description of the issue]

## Environment
- RouterOS Version: 7.15
- Board: RB4011iGS+
- Bot Version: 1.0.0

## Steps to Reproduce
1. Send command `/status`
2. Wait for response
3. Error occurs

## Expected Behavior
Bot should respond with system status

## Actual Behavior
Bot returns error message

## Logs
```
[Paste relevant log entries]
```

## Additional Context
[Any other relevant information]
```

### Suggesting Features

Have an idea? We'd love to hear it!

**Feature Request Template:**
```markdown
## Feature Description
[Clear description of the feature]

## Use Case
[Why is this feature needed?]

## Proposed Implementation
[How might this work?]

## Alternatives Considered
[Any alternative solutions?]

## Additional Context
[Screenshots, examples, references]
```

## Code Contributions

### Getting Started

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourusername/mikrotik-telegram-bot.git
   cd mikrotik-telegram-bot
   ```

2. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the style guidelines
   - Add comments where needed
   - Update documentation

4. **Test your changes**
   - Test on a RouterOS device
   - Verify all commands work
   - Check for errors in logs

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add: Brief description of your change"
   ```

6. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**
   - Describe your changes
   - Reference any related issues
   - Add screenshots if applicable

### Commit Message Format

Use clear, descriptive commit messages:

```
Type: Brief description (50 chars or less)

Detailed explanation if needed (wrap at 72 chars)

- Bullet points for specific changes
- Reference issues: Fixes #123

Types: Add, Update, Fix, Remove, Refactor, Docs, Test
```

**Examples:**
```
Add: /wireless command for WiFi client list

Fix: CPU monitoring threshold not working correctly

Update: Improve backup rotation logic

Docs: Add examples for multi-device management
```

## Documentation

Documentation is just as important as code!

### Areas to Contribute

- **README improvements**: Clarity, examples, screenshots
- **Setup guides**: Alternative methods, troubleshooting
- **Usage examples**: Real-world scenarios, tips
- **Code comments**: Explain complex logic
- **Translations**: Help make docs multilingual

### Documentation Style

- Use clear, simple language
- Include code examples
- Add screenshots where helpful
- Keep formatting consistent
- Test all commands before documenting

## Testing

### Manual Testing Checklist

Before submitting, test:

- [ ] Bot responds to `?` command
- [ ] `/help` shows command list
- [ ] `/status` returns system information
- [ ] Device activation works (`! identity`)
- [ ] Command execution works
- [ ] Monitoring alerts trigger correctly
- [ ] Backup creation succeeds
- [ ] No errors in logs
- [ ] Works on RouterOS 7.15+

### Testing on Different Platforms

If possible, test on:
- Different RouterOS versions (7.15, 7.16, etc.)
- Different hardware (RB, CCR, CRS, CHR)
- Different configurations (wireless, VPN, VLAN)

## Style Guidelines

### RouterOS Script Style

```routeros
# Use descriptive variable names
:local SystemStatus "active"

# Add comments for complex logic
# Check if CPU exceeds threshold
:if ($CPULoad > $Threshold) do={
  # Send alert
}

# Use consistent indentation (2 spaces)
:foreach Interface in=$InterfaceList do={
  :local Status [/interface get $Interface running]
}

# Group related code with blank lines
:local CPU [/system resource get cpu-load]
:local RAM [/system resource get free-memory]

:if ($CPU > 80) do={
  # Alert code
}
```

### Documentation Style

- Use Markdown formatting
- Include code blocks with syntax highlighting
- Add links to related documentation
- Use emojis sparingly and meaningfully
- Keep line length reasonable (80-100 chars)

### File Organization

```
mikrotik-telegram-bot/
├── scripts/
│   ├── bot-core.rsc          # Main bot logic
│   ├── bot-config.rsc        # Configuration
│   └── modules/              # Feature modules
│       ├── monitoring.rsc
│       ├── backup.rsc
│       └── custom-commands.rsc
├── setup/                    # Setup documentation
├── examples/                 # Usage examples
└── README.md
```

## Development Workflow

### Workflow for New Features

1. **Discuss first**: Open an issue to discuss the feature
2. **Design**: Plan the implementation
3. **Implement**: Write the code
4. **Test**: Thoroughly test on RouterOS
5. **Document**: Update docs and examples
6. **Submit**: Create a pull request

### Code Review Process

1. Maintainer reviews your PR
2. Feedback provided if needed
3. You make requested changes
4. PR approved and merged

## Community

### Where to Get Help

- **Telegram Group**: [@routeros_scripts](https://t.me/routeros_scripts)
- **GitHub Issues**: For bugs and features
- **Discussions**: For questions and ideas

### Recognition

Contributors are recognized in:
- README.md contributors section
- CHANGELOG.md for significant contributions
- GitHub contributors page

## License

By contributing, you agree that your contributions will be licensed under the GPL-3.0 License.

## Questions?

Don't hesitate to ask! Open an issue or reach out in the Telegram group.

---

**Thank you for contributing to MikroTik Telegram Bot!** 🙏

