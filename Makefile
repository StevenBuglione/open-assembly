.PHONY: phase0 gate

phase0:
	tools/gate --phase0

gate:
	tools/gate "$(FUNC)"
