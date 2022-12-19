package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"

	appcatv1 "github.com/vshn/component-appcat/apis/v1"
)

// Remove some fields that are removed by Crossplane anyway.
// Some properties need to be added and removed by Crossplane (https://doc.crds.dev/github.com/crossplane/crossplane/apiextensions.crossplane.io/CompositeResourceDefinition/v1@v1.10.0)
//go:generate yq -i e ../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml --expression "with(.spec.versions[].schema.openAPIV3Schema.properties; del(.metadata), del(.kind), del(.apiVersion))"
//go:generate yq -i e ../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml --expression "with(.spec.versions[]; .referenceable=true, del(.storage), del(.subresources))"

// Workaround to make nested defaulting work.
// kubebuilder is unable to set a {} default
//go:generate yq -i e ../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml --expression "with(.spec.versions[]; .schema.openAPIV3Schema.properties.spec.properties.parameters.default={})"
//go:generate yq -i e ../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml --expression "with(.spec.versions[]; .schema.openAPIV3Schema.properties.spec.properties.parameters.properties.maintenance.default={})"
//go:generate yq -i e ../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml --expression "with(.spec.versions[]; .schema.openAPIV3Schema.properties.spec.properties.parameters.properties.backup.default={})"
//go:generate yq -i e ../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml --expression "with(.spec.versions[]; .schema.openAPIV3Schema.properties.spec.properties.parameters.properties.service.default={})"
//go:generate yq -i e ../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml --expression "with(.spec.versions[]; .schema.openAPIV3Schema.properties.spec.properties.parameters.properties.size.default={})"
//go:generate yq -i e ../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml --expression "with(.spec.versions[]; .schema.openAPIV3Schema.properties.spec.properties.parameters.properties.network.default={})"

// Patch the XRD with this generated CRD scheme
//go:generate yq -i e ../../../packages/composite/dbaas/exoscale/mysql.yml --expression ".parameters.appcat.composites.\"xexoscalemysqls.exoscale.appcat.vshn.io\".spec.versions=load(\"../../generated/exoscale.appcat.vshn.io_exoscalemysqls.yaml\").spec.versions"

// +kubebuilder:object:root=true
// +kubebuilder:printcolumn:name="Plan",type="string",JSONPath=".spec.parameters.size.plan"
// +kubebuilder:printcolumn:name="Zone",type="string",JSONPath=".spec.parameters.service.zone"

// ExoscaleMySQL is the API for creating MySQL on Exoscale.
type ExoscaleMySQL struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// Spec defines the desired state of a ExoscaleMySQL.
	Spec ExoscaleMySQLSpec `json:"spec,omitempty"`
	// Status reflects the observed state of a ExoscaleMySQL.
	Status ExoscaleMySQLStatus `json:"status,omitempty"`
}

type ExoscaleMySQLSpec struct {
	// Parameters are the configurable fields of a ExoscaleMySQL.
	Parameters ExoscaleMySQLParameters `json:"parameters,omitempty"`
}

type ExoscaleMySQLParameters struct {
	// Service contains Exoscale MySQL DBaaS specific properties
	Service ExoscaleMySQLServiceSpec `json:"service,omitempty"`

	// Maintenance contains settings to control the maintenance of an instance.
	Maintenance ExoscaleDBaaSMaintenanceScheduleSpec `json:"maintenance,omitempty"`

	// Size contains settings to control the sizing of a service.
	Size ExoscaleDBaaSSizeSpec `json:"size,omitempty"`

	// Network contains any network related settings.
	Network ExoscaleDBaaSNetworkSpec `json:"network,omitempty"`

	// Backup contains settings to control the backups of an instance.
	Backup ExoscaleDBaaSBackupSpec `json:"backup,omitempty"`
}

type ExoscaleMySQLServiceSpec struct {
	ExoscaleDBaaSServiceSpec `json:",inline"`

	// +kubebuilder:validation:Enum="8"
	// +kubebuilder:default="8"

	// MajorVersion contains the major version for MySQL.
	// Currently only "8" is supported. Leave it empty to always get the latest supported version.
	MajorVersion string `json:"majorVersion,omitempty"`

	// MySQLSettings contains additional MySQL settings.
	MySQLSettings runtime.RawExtension `json:"mysqlSettings,omitempty"`
}

type ExoscaleMySQLStatus struct {
	// MySQLConditions contains the status conditions of the backing object.
	MySQLConditions []appcatv1.Condition `json:"mysqlConditions,omitempty"`
}
