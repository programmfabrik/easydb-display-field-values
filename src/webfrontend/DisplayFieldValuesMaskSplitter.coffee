class ez5.DisplayFieldValuesMaskSplitter extends CustomMaskSplitter

	@FIELD_NAMES_REGEXP = /%([a-z][a-zA-Z0-9_:\-]{0,61}[a-zA-Z0-9])%/g

	isSimpleSplit: ->
		return true

	renderAsField: ->
		return true

	getOptions: ->
		textHintButton = new CUI.Button
			text: $$("display-field-values.custom.splitter.text.hint-text")
			appearance: "flat"
			onClick: =>
				fieldNames = []
				for node in @father.children
					fieldName = node.getData().field_name
					field = node.getData().field?._column
					if not fieldName or not field
						continue
					if field.type == "daterange"
						fieldNames.push("#{fieldName}:from")
						fieldNames.push("#{fieldName}:to")
					else if field.type == "eas"
						# TODO
					else if field.type in ["text_l10n", "text_l10n_oneline"]
						fieldNames.push("#{fieldName}:best")
						for lang in ez5.loca.getDatabaseLanguages()
							fieldNames.push("#{fieldName}:#{lang}")
						continue
					else if field.type == "link"
						fieldNames.push("#{fieldName}:standard-1")
						fieldNames.push("#{fieldName}:standard-2")
						fieldNames.push("#{fieldName}:standard-3")
					else
						fieldNames.push(fieldName)

				fieldNames = fieldNames.concat(fieldNames.map((fieldName) -> "#{fieldName}:urlencoded")).sort()
				text = $$("display-field-values.custom.splitter.text.hint-content", fields: fieldNames)

				content = new CUI.Label
					text: text
					markdown: true
				pop = new ez5.HintPopover
					element: textHintButton
					content: content
					padded: true
				pop.show()

		fields = [
			type: CUI.Input
			name: "text"
			min_rows: 9
			textarea: true
			maximize_horizontal: true
			class: "ez5-display-field-values-text-input"
			form:
				label: $$("display-field-values.custom.splitter.text.label")
				hint: textHintButton
			onDataChanged: (_, field) =>
				CUI.Events.trigger
					node: field
					type: "content-resize"
				return
		,
			type: CUI.Checkbox
			name: "output_empty"
			form:
				label: $$("display-field-values.custom.splitter.output_empty.label")
		,
			type: CUI.Checkbox
			name: "dont_escape_markdown_in_values"
			form:
				label: $$("display-field-values.custom.splitter.dont_escape_markdown_in_values.label")
		]

		return fields

	getDefaultOptions: ->
		defaultOpts =
			output_empty: false
			dont_escape_markdown_in_values: false
			text: ""
		return defaultOpts

	renderField: (opts) ->
		dataOptions = @getDataOptions()
		if not dataOptions.text
			return

		data = opts.data
		fieldNames = @__getFieldNames(dataOptions.text)
		label = new CUI.Label(text: "", markdown: true)

		setText = =>
			values = @__getValues(data, fieldNames)
			if !dataOptions.output_empty and fieldNames.length > 0 and CUI.util.isEmpty(values)
				label.hide()
			else
				label.show()

			text = @__getLabelText(dataOptions, values)
			label.setText(text)
		setText()

		if opts.mode != "editor" or not opts.editor?.__mainPane
			return label

		CUI.Events.listen
			type: "editor-changed"
			node: opts.editor.__mainPane # Cannot use the getter because it builds the main pane instead of returning it.
			call: =>
				setText()
				return

		return label

	isEnabledForNested: ->
		return true

	__getLabelText: (dataOptions, values) ->
		text = dataOptions.text
		dontEscapeMarkdownInValues = dataOptions.dont_escape_markdown_in_values
		replacements = @__getFieldNames(text, false)

		doReplace = (field, _value) ->
			regexp = new RegExp("%#{field}:urlencoded%", "g")
			text = text.replace(regexp, encodeURI(_value))

			if not dontEscapeMarkdownInValues
				_value = MarkdownEscape.escape(_value)

			regexp = new RegExp("%#{field}%", "g")
			text = text.replace(regexp, _value)

		for fieldName, value of values
			if CUI.util.isPlainObject(value)
				if value._standard
					for i in [1,2,3]
						if not value._standard[i]?.text
							continue
						bestValue = ez5.loca.getBestFrontendValue(value._standard[i].text)
						doReplace("#{fieldName}:standard-#{i}", bestValue)
				else
					bestValue = ez5.loca.getBestFrontendValue(value)
					if not CUI.util.isEmpty(bestValue)
						doReplace("#{fieldName}:best", bestValue)

					if not CUI.util.isEmpty(value.value) # For dates, for example.
						doReplace("#{fieldName}", value.value)

					for key, _value of value
						if CUI.util.isEmpty(_value) or CUI.util.isPlainObject(_value)
							continue
						_field = "#{fieldName}:#{key}"
						doReplace(_field, _value)
			else
				doReplace(fieldName, value)

		# Remove all unused placeholders with empty.
		for replacement in replacements
			regexp = new RegExp("%#{replacement}%", "g")
			text = text.replace(regexp, "")
		return text

	__getValues: (data, fieldNames) ->
		values = {}
		for fieldName in fieldNames
			value = data[fieldName]
			if CUI.util.isEmpty(value)
				continue

			if CUI.util.isPlainObject(value)
				if not Object.values(value).some((_val) -> not CUI.util.isEmpty(_val))
					continue

			values[fieldName] = value
		return values

	__getFieldNames: (text, removeSuffix = true) ->
		fieldNames = new Set()
		matches = text.matchAll(ez5.DisplayFieldValuesMaskSplitter.FIELD_NAMES_REGEXP)
		while values = matches.next()?.value
			if values[1]
				fieldName = values[1]
				if removeSuffix
					fieldName = fieldName.replace(/:(.*)/g, "")
				fieldNames.add(fieldName)
		return Array.from(fieldNames)

MaskSplitter.plugins.registerPlugin(ez5.DisplayFieldValuesMaskSplitter)
