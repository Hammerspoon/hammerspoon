# {{ title }}
---

## Project Links
| Resource        | Link                             |
| --------------- | -------------------------------- |
{% for link in links %}
| {{ link.name }} | [{{ link.url }}]({{ link.url }}) |
{% endfor %}

## API Documentation
| Module                                                             | Description           |
| ------------------------------------------------------------------ | --------------------- |
{% for module in data %}
| [{{ module.name }}]({{ module.name }}.md)                          | {{ module.desc }}     |
{% endfor %}
