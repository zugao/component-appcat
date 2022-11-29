package v1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// Remove some fields that are removed by Crossplane anyway.
// Some properties need to be added and removed by Crossplane (https://doc.crds.dev/github.com/crossplane/crossplane/apiextensions.crossplane.io/CompositeResourceDefinition/v1@v1.10.0)
//go:generate yq -i e ../generated/appcat.vshn.io_exoscalekafkas.yaml --expression "with(.spec.versions[].schema.openAPIV3Schema.properties; del(.metadata), del(.kind), del(.apiVersion))"
//go:generate yq -i e ../generated/appcat.vshn.io_exoscalekafkas.yaml --expression "with(.spec.versions[]; .referenceable=true, del(.storage), del(.subresources))"

// Patch the XRD with this generated CRD scheme
//go:generate yq -i e ../../packages/composite/dbaas/exoscale/kafka.yml --expression ".parameters.appcat.composites.\"xexoscalekafkas.appcat.vshn.io\".spec.versions=load(\"../generated/appcat.vshn.io_exoscalekafkas.yaml\").spec.versions"

// +kubebuilder:object:root=true
// +kubebuilder:printcolumn:name="Plan",type="string",JSONPath=".spec.parameters.size.plan"
// +kubebuilder:printcolumn:name="Zone",type="string",JSONPath=".spec.parameters.service.zone"

// ExoscaleKafka is the API for creating Kafka instances on Exoscale.
type ExoscaleKafka struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	// Spec defines the desired state of a ExoscaleKafka.
	Spec ExoscaleKafkaSpec `json:"spec,omitempty"`
	// Status reflects the observed state of a ExoscaleKafka.
	Status ExoscaleKafkaStatus `json:"status,omitempty"`
}

type ExoscaleKafkaSpec struct {
	// Parameters are the configurable fields of a ExoscaleKafka.
	Parameters ExoscaleKafkaParameters `json:"parameters,omitempty"`
}

type ExoscaleKafkaParameters struct {
	// Service contains Exoscale Kafka DBaaS specific properties
	Service ExoscaleKafkaServiceSpec `json:"service,omitempty"`

	// Maintenance contains settings to control the maintenance of an instance.
	Maintenance ExoscaleDBaaSMaintenanceScheduleSpec `json:"maintenance,omitempty"`

	// Size contains settings to control the sizing of a service.
	Size ExoscaleDBaaSSizeSpec `json:"size,omitempty"`

	// Network contains any network related settings.
	Network ExoscaleDBaaSNetworkSpec `json:"network,omitempty"`
}

type ExoscaleKafkaServiceSpec struct {
	ExoscaleDBaaSServiceSpec `json:",inline"`
	// KafkaSettings contains additional Kafka settings.
	KafkaSettings runtime.RawExtension `json:"kafkaSettings,omitempty"`
}

type ExoscaleKafkaStatus struct {
	// KafkaConditions contains the status conditions of the backing object.
	KafkaConditions []Condition `json:"kafkaConditions,omitempty"`
}
