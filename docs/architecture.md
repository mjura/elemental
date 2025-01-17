# Architecture

The Elemental stack can be divided in two main parts: the Elemental OS, which comprises the tools and the steps needed to prepare the Cloud Native OS image and perform the actual OS installation on the host, and the {{elemental.operator.name}}, that allows central management of the Elemental OS via Rancher, the Kubernetes way.

## Elemental OS
In order to deploy the Elemental OS we need:

- an Elemental base OS image
- an Elemental installation configuration
- the {{elemental.cli.name}} tool, which installs the Elemental OS image on the target host applying the Elemental installation configuration

### Elemental OS image
The Elemental OS image is an OCI container image containing all the files that will make up the OS of the target host. It will contain not only all the desired binaries and libraries, but also the kernel and the boot files required by a linux system.
The [{{elemental.toolkit.name}}]({{elemental.toolkit.url}}) is at the core of the Elemental OS, enabling to boot and upgrade an OS from container images. It also provides a framework that allows to combine different packages to bake custom OS container images. For more information check the [{{elemental.toolkit.name}} project page]({{elemental.toolkit.url}}).

### Elemental installation configuration
In order to provision a machine with an Elemental OS image, installation configuration parameters are required: things such as the boot device, the root password, system configuration, users and custom files are things that should be provided aside from the Elemental OS image. All the data can be provided in a single .yaml file. More details can be found in the [{{elemental.toolkit.name}} documentation]({{elemental.toolkit.url}}).

### {{elemental.cli.name}}
{{elemental.cli.name}} is the tool that allows to turn the Elemental OS image in a bootable and installed OS: it can generate an {{elemental.iso.name}} image from the provided Elemental OS container image. The generated {{elemental.iso.name}} image can be used to boot a virtual machine or a bare metal host and start the Elemental OS installation.

The {{elemental.cli.name}} allows also the Elemental OS installation on the storage device of the live booted host, applying the Elemental installation configuration passed in inout. For the list and syntax of the commands available in the {{elemental.cli.name}}, check the [online documentation]({{elemental.cli.url}}).

## {{elemental.operator.name}}
The {{elemental.operator.name}} is responsible for managing OS upgrades and managing a secure device inventory to assist
with zero touch provisioning.
It provides an {{elemental.operator.name}} Helm Chart and an {{elemental.register.name}}.

### {{elemental.operator.name}} Helm Chart
The {{elemental.operator.name}} Helm Chart must be installed on a Rancher Cluster. It enables new hosts to:

- register against the {{elemental.operator.name}}.
- retrieve the Elemental installation configuration required for the Elemental OS installation from Kubernetes resources.
- download and install the [{{ranchersystemagent.name}}]({{ranchersystemagent.url}}), which enables Rancher to provision and manage K3s and RKE2 on the Elemental nodes.

The {{elemental.operator.name}} allows control of the Elemental Nodes by extending the Kubernetes APIs with a set of _elemental.cattle.io_ [Kubernetes CRDs](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/):

- MachineRegistration
- MachineInventory
- MachineInventorySelector
- MachineInventorySelectorTemplate
- ManagedOSImage
- ManagedOSVersion
- ManagedOSVersionChannel

#### MachineRegistration
The MachineRegistration includes the Elemental installation configuration (provided by the user) and a registration token (generated by the {{elemental.operator.name}}), from which a registration URL is derived.

The registration URL is the way through which an host can access the {{elemental.operator.name}} services, to kick off the Elemental provisioning process.

The MachineRegistration has a `Ready` condition which turns to true when the {{elemental.operator.name}} has successfully generated the registration URL and an associated ServiceAccount. From this point on the target host can connect to the registration URL to kick off the provisioning process.

An HTTP GET request against the registration URL returns the _registration file_: a .yaml file containing the registration data (i.e., the _spec:config:elemental:registration_ section only from the just created MachineRegistration).
The registration file contains all the required data to allow the target host to perform self registration and start the Elemental provisioning. See the [config:elemental:registration section in the MachineRegistration reference](machineregistration-reference#configelementalregistration)) for more details on the available registration options.


#### MachineInventory
When a new host registers successfully, the {{elemental.operator.name}} creates a MachineInventory resource representing that particular host.
The MachineInventory stores the TPM hash of the tracked host, retrieved during the registration process, and allows to execute arbitrary commands (plans) on the machine.

A MachineInventory has three conditions:

- `Initialized`, tracking if the resources needed for applying the plan have been correctly created.
- `PlanReady`, showing if the host has completed its current plan.
- `Ready`, which indicates that a machine has been initialized and has no running plans.

#### MachineInventorySelector
A MachineInventorySelector selects MachineInventories based on applied selectors (usually patter matching on MachineInventory label values).

MachineInventorySelectors have three conditions:

- `InventoryReady`, turn to true if the MachineInventorySelector has found a matching MachineInventory and has successful set itself as the MachineInventorySelector owner.
- `BootstrapReady`, reports if the selector has successfully applied its bootstrap plan.
- `Ready`, tracks if the inventory has been correctly selected and bootstrapped.

#### MachineInventorySelectorTemplate
The MachineInventorySelectorTemplate is a user defined resource that will be used as the blueprint to create the required MachineInventorySelectors: it includes the selector to identify the eligible MachineInventories.


### {{elemental.register.name}}
New hosts start the Elemental provisioning process through the {{elemental.register.name}}: this tool requires a valid elemental-operator registration URL as input, and performs the following steps:

- setups a websocket connection to the registration URL
- authenticates itself using the registration token and the onboard TPM<sup>1</sup>
- sends [SMBIOS data](smbios.md) to the {{elemental.operator.name}}
- retrieves the Elemental installation configuration
- starts the {{elemental.cli.name}} and performs the Elemental OS installation
- reboots in the newly installed Elemental OS

<sup>1</sup> _if no TPM 2.0 is available on the host, TPM can be emulated by software: see the `emulate-tpm` key in the [config.elemental.register reference document](machineregistration-reference.md#configelementalregistration)_


{{elemental.iso.name}}
The {{elemental.iso.name}} is a temporary OS based on Elemental (an Elemental live ISO).
Elemental is a set of tools to provide and manage the OS of Kubernetes nodes.
The OS is:

- immutable and customizable, built on the [{{elemental.toolkit.name}}](https://rancher.github.io/elemental-toolkit/)
- centrally managed via [Rancher](https://rancher.com)


{{elemental.operator.name}} includes a Kubernetes operator installed in the management cluster and a client
side installed in nodes, so they can self register into the management cluster. Once a node is
registered the {{elemental.operator.name}} will kick-start the OS installation and schedule the Kubernetes
provisioning using the [{{ranchersystemagent.name}}]({{ranchersystemagent.url}}).
Rancher System Agent is responsible for bootstrapping RKE2/k3s and Rancher from an OCI registry. This means
an update of containerd, k3s, RKE2, or Rancher does not require an OS upgrade
or node reboot.

## Elemental Teal

Elemental Teal is the OS, based on SUSE Linux Enterprise (SLE) Micro for Rancher,
built using the Elemental stack. The only assumption from the Elemental stack is that
the underlying distribution is based on Systemd. We choose SLE Micro for Rancher for
obvious reasons, but beyond that Elemental provides a stable layer to build upon
that is well tested and has paths to commercial support, if one chooses.
