# Hammerspoon docs: {{ module.name }}

{{ module.doc }}
{% if module["submodules"]|length > 0 %}

## Submodules
{% for submodule in module["submodules"] %}
 * [{{ module.name }}.{{ submodule }}]({{ module.name }}.{{ submodule }}.md)
{% endfor %}
{% endif %}

## API Overview
{% for type in type_order %}
{# Considering: {{ type }} ({{ module[type]|length }}) #}
{% if module[type]|length > 0 %}
* {{ type }}s - {{ type_desc[type] }}</li>
{% for item in module[type] %}
  * {{ item.name }}
{% endfor %}
{% endif %}
{% endfor %}

## API Documentation
{% for type in type_order %}
{% if module[type]|length > 0 %}

### {{ type}}s
{% for item in module[type] %}

#### {{ item.name }}
  * Signature: {{ item.def }}
  * Type: {{ item.type }}
  * Description: {{ item.desc }}
{% if item.stripped_doc|length > 0 %}
  {{ item.stripped_doc|indent(4) }}
{% endif %}
{% if "parameters" in item %}
  * Parameters:
  {% for parameter in item.parameters %}
    {{ parameter }}
  {% endfor %}
{% endif %}
{% if "returns" in item %}
  * Returns:
  {% for return in item.returns %}
    {{ return }}
  {% endfor %}
{% endif %}
{% if "notes" in item %}
  * Notes:
  {% for note in item.notes %}
    {{ note }}
  {% endfor %}
{% endif %}
{% endfor %}
{% endif %}
{% endfor %}
