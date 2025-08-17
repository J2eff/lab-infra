PACKER_VERSION := 1.10.0
QEMU_VERSION := 8.2.0

.PHONY: prepare install-deps install-tfenv install-packer install-qemu install-libvirt-packer setup-sudoers configure-libvirt check clean

prepare: install-deps install-tfenv install-packer install-qemu install-libvirt-packer setup-sudoers configure-libvirt
	@echo "✅ Setup complete!"

install-deps:
	@echo "🔧 Installing required packages..."
	sudo apt update && sudo apt install -y \
		curl wget unzip git \
		qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst
	@echo "🔧 Configuring libvirt group permissions..."
	@USER=$$(whoami); \
	for group in libvirt kvm; do \
		if id -nG "$$USER" | grep -qw "$$group"; then \
			echo "✅ $$USER is already in the $$group group."; \
		else \
			echo "➕ Adding $$USER to $$group group..."; \
			sudo usermod -aG $$group $$USER && echo "✅ Added successfully"; \
			NEED_RELOGIN=true; \
		fi; \
	done; \
	if [ "$$NEED_RELOGIN" = true ]; then \
		echo "⚠️  Please log out or reboot to apply group changes."; \
	fi

install-tfenv:
	@echo "⬇️ Installing tfenv..."
	@if [ ! -d "$(HOME)/.tfenv" ]; then \
		git clone https://github.com/tfutils/tfenv.git ~/.tfenv && \
		echo 'export PATH="$$HOME/.tfenv/bin:$$PATH"' >> ~/.bashrc && \
		echo '✅ tfenv installed. Please restart your terminal.'; \
	else \
		echo "⚠️ tfenv is already installed."; \
	fi

install-packer:
	@echo "⬇️ Installing packer $(PACKER_VERSION)..."
	@if ! command -v packer >/dev/null 2>&1; then \
		wget https://releases.hashicorp.com/packer/$(PACKER_VERSION)/packer_$(PACKER_VERSION)_linux_amd64.zip && \
		unzip -o packer_$(PACKER_VERSION)_linux_amd64.zip && \
		sudo mv packer /usr/local/bin/ && \
		rm packer_$(PACKER_VERSION)_linux_amd64.zip && \
		echo "✅ packer installation complete"; \
	else \
		echo "⚠️ packer is already installed."; \
	fi

install-qemu:
	@echo "⬇️ Installing QEMU ($(QEMU_VERSION) or nearest available via apt)..."
	sudo apt update && sudo apt install -y qemu-system-x86 qemu-utils
	@echo "✅ QEMU installed (version may vary based on repository)."

install-libvirt-packer:
	@echo "🔌 Initializing packer plugins (including QEMU plugin)..."
	@bash -c 'pushd base/packer > /dev/null && packer init ubuntu.pkr.hcl && popd > /dev/null'

setup-sudoers:
	@echo "🔐 Setting up passwordless sudo..."
	@USER_NAME=$$(whoami); \
	SUDOERS_FILE="/etc/sudoers.d/$$USER_NAME"; \
	if [ ! -f "$$SUDOERS_FILE" ]; then \
		echo "$$USER_NAME ALL=(ALL) NOPASSWD:ALL" | sudo tee $$SUDOERS_FILE > /dev/null && \
		sudo chmod 0440 $$SUDOERS_FILE && \
		echo "✅ Passwordless sudo configured for $$USER_NAME"; \
	else \
		echo "⚠️  Sudoers file already exists: $$SUDOERS_FILE"; \
	fi

configure-libvirt:
	@echo "👤 Verifying kvm and libvirt group membership..."
	@if ! groups $(whoami) | grep -q '\bkvm\b'; then \
		echo "ℹ️  Adding current user to kvm group..."; \
		sudo usermod -aG kvm $(whoami); \
	else \
		echo "✅ User already in kvm group."; \
	fi
	@if ! groups $(whoami) | grep -q '\blibvirt\b'; then \
		echo "ℹ️  Adding current user to libvirt group..."; \
		sudo usermod -aG libvirt $(whoami); \
	else \
		echo "✅ User already in libvirt group."; \
	fi

	@echo "⚙️  Updating /etc/libvirt/qemu.conf..."
	@sudo sed -i 's|^#\?\s*security_driver\s*=.*|security_driver = "none"|' /etc/libvirt/qemu.conf && \
	echo "✅ Set security_driver = \"none\" successfully"

check:
	@echo "🧪 Packer version: $$(packer version | head -n 1)"
	@echo "🧪 QEMU version: $$(qemu-system-x86_64 --version | head -n 1)"
	
clean:
	@echo "🧹 Cleaning up build artifacts..."
	rm -f packer_$(PACKER_VERSION)_linux_amd64.zip
	rm -rf output/*.qcow2