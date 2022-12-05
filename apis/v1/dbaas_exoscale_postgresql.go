package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// Remove some fields that are removed by Crossplane anyway.
// Some properties need to be added and removed by Crossplane (https://doc.crds.dev/github.com/crossplane/crossplane/apiextensions.crossplane.io/CompositeResourceDefinition/v1@v1.10.0)
//go:generate yq -i e ../generated/appcat.vshn.io_exoscalepostgresqls.yaml --expression "with(.spec.versions[].schema.openAPIV3Schema.properties; del(.metadata), del(.kind), del(.apiVersion))"
//go:generate yq -i e ../generated/appcat.vshn.io_exoscalepostgresqls.yaml --expression "with(.spec.versions[]; .referenceable=true, del(.storage), del(.subresources))"

// Patch the XRD with this generated CRD scheme
//go:generate yq -i e ../../packages/composite/dbaas/exoscale/postgres.yml --expression ".parameters.appcat.composites.\"xexoscalepostgresqls.appcat.vshn.io\".spec.versions=load(\"../generated/appcat.vshn.io_exoscalepostgresqls.yaml\").spec.versions"

// +kubebuilder:object:root=true
// +kubebuilder:printcolumn:name="Plan",type="string",JSONPath=".spec.parameters.size.plan"
// +kubebuilder:printcolumn:name="Zone",type="string",JSONPath=".spec.parameters.service.zone"

// ExoscalePostgreSQL is the API for creating PostgreSQL on Exoscale.
type ExoscalePostgreSQL struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// Spec defines the desired state of a ExoscalePostgreSQL.
	Spec ExoscalePostgreSQLSpec `json:"spec,omitempty"`
	// Status reflects the observed state of a ExoscalePostgreSQL.
	Status ExoscalePostgreSQLStatus `json:"status,omitempty"`
}

type ExoscalePostgreSQLSpec struct {
	// Parameters are the configurable fields of a ExoscalePostgreSQL.
	Parameters ExoscalePostgreSQLParameters `json:"parameters,omitempty"`
}

type ExoscalePostgreSQLParameters struct {
	// Service contains Exoscale PostgreSQL DBaaS specific properties
	Service ExoscalePostgreSQLServiceSpec `json:"service,omitempty"`

	// Maintenance contains settings to control the maintenance of an instance.
	Maintenance ExoscaleDBaaSMaintenanceScheduleSpec `json:"maintenance,omitempty"`

	// Size contains settings to control the sizing of a service.
	Size ExoscaleDBaaSSizeSpec `json:"size,omitempty"`

	// Network contains any network related settings.
	Network ExoscaleDBaaSNetworkSpec `json:"network,omitempty"`

	// Backup contains settings to control the backups of an instance.
	Backup ExoscaleDBaaSBackupSpec `json:"backup,omitempty"`
}

type ExoscalePostgreSQLServiceSpec struct {
	ExoscaleDBaaSServiceSpec `json:",inline"`

	// +kubebuilder:validation:Enum="14"

	// MajorVersion contains the major version for PostgreSQL.
	// Currently only "14" is supported. Leave it empty to always get the latest supported version.
	MajorVersion string `json:"majorVersion,omitempty"`

	// PGSettings contains additional PostgreSQL settings.
	PostgreSQLSettings runtime.RawExtension `json:"pgSettings,omitempty"`
}

type ExoscalePostgreSQLStatus struct {
	// PostgreSQLConditions contains the status conditions of the backing object.
	PostgreSQLConditions []Condition `json:"postgresqlConditions,omitempty"`
}
