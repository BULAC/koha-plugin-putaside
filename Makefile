FILES=Koha/Plugin/Fr/Bulac/PutAside.pm Koha/Plugin/Fr/Bulac/PutAside/i18n.pm Koha/Plugin/Fr/Bulac/PutAside/tool-PutAside.tt Koha/Plugin/Fr/Bulac/PutAside/i18n/default.inc Koha/Plugin/Fr/Bulac/PutAside/i18n/en.inc Koha/Plugin/Fr/Bulac/PutAside/i18n/fr-FR.inc Koha/Plugin/Fr/Bulac/PutAside/configure.tt

koha-plugin-putaside.kpz: $(FILES)
	zip koha-plugin-putaside.kpz $(FILES)

clean:
	find . -name '*~' -delete
	rm koha-plugin-putaside.kpz
