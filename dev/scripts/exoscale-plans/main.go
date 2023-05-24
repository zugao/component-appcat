package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	egoscalev2 "github.com/exoscale/egoscale/v2"
	"k8s.io/apimachinery/pkg/api/resource"
)

var (
	defaultZone     = "ch-gva-2"
	deafultLocation = "../../../component/exoscale-plans/"
)

type Plan struct {
	Note string `json:"note,omitempty"`
	Size Size   `json:"size,omitempty"`
}

type Size struct {
	CPU    string `json:"cpu,omitempty"`
	Disk   string `json:"disk,omitempty"`
	Memory string `json:"memory,omitempty"`
}

func main() {

	apiKey := os.Getenv("EXOSCALE_API_KEY")
	if apiKey == "" {
		println("Please provide EXOSCALE_API_KEY env variable")
		os.Exit(1)
	}

	apiSecret := os.Getenv("EXOSCALE_API_SECRET")
	if apiSecret == "" {
		println("Please provide EXOSCALE_API_KEY env variable")
		os.Exit(1)
	}

	ec, err := egoscalev2.NewClient(apiKey, apiSecret)
	if err != nil {
		panic(err)
	}

	saveServicesJSON(getPlans(ec))

}

func getPlans(ec *egoscalev2.Client) []*egoscalev2.DatabaseServiceType {

	serviceList, err := ec.ListDatabaseServiceTypes(context.TODO(), defaultZone)
	if err != nil {
		panic(err)
	}

	return serviceList
}

func saveServicesJSON(serviceList []*egoscalev2.DatabaseServiceType) {

	for _, service := range serviceList {

		fmt.Println("Processing", *service.Name)

		plans := map[string]Plan{}

		for _, plan := range service.Plans {
			plans[*plan.Name] = Plan{
				Note: *service.Name + " " + *plan.Name,
				Size: Size{
					Disk:   resource.NewQuantity(*plan.DiskSpace, resource.BinarySI).String(),
					CPU:    resource.NewQuantity(*plan.NodeCPUs, resource.DecimalSI).String(),
					Memory: resource.NewQuantity(*plan.NodeMemory, resource.BinarySI).String(),
				},
			}
		}

		marshalledPlan, err := json.Marshal(plans)
		if err != nil {
			panic(err)
		}

		// eclint wants a newline at the end of the file.
		marshalledPlan = append(marshalledPlan, []byte("\n")...)
		err = os.WriteFile(deafultLocation+*service.Name+".json", marshalledPlan, 0644)
		if err != nil {
			panic(err)
		}
	}

}
