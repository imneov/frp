package kubernetes

import (
	"reflect"
	"testing"
)

func TestGenerateServiceName(t *testing.T) {
	tests := []struct {
		name    string
		info    ServiceInfo
		want    string
		wantErr bool
	}{
		{
			name: "minimal without path and metadata",
			info: ServiceInfo{Protocol: "http", Name: "svc", Namespace: "ns", Cluster: "cluster", Port: 80},
			want: "http://svc.ns.cluster:80",
		},
		{
			name: "with type only",
			info: ServiceInfo{Protocol: "tcp", Name: "svc", Namespace: "ns", Cluster: "cluster", Port: 7000, Type: "svc"},
			want: "tcp://svc.ns.cluster:7000/svc",
		},
		{
			name: "with type and IP",
			info: ServiceInfo{Protocol: "udp", Name: "svc", Namespace: "ns", Cluster: "cluster", Port: 7000, Type: "pod", IP: "10.0.0.1"},
			want: "udp://svc.ns.cluster:7000/pod/10.0.0.1",
		},
		{
			name: "with metadata",
			info: ServiceInfo{Protocol: "http", Name: "svc", Namespace: "ns", Cluster: "cluster", Port: 80, Metadata: map[string]string{"a": "1", "b": "2"}},
			want: "http://svc.ns.cluster:80?a=1&b=2",
		},
		{
			name:    "missing required field",
			info:    ServiceInfo{Name: "svc"},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := GenerateServiceName(tt.info)
			if (err != nil) != tt.wantErr {
				t.Errorf("GenerateServiceName() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if err == nil && got != tt.want {
				t.Errorf("GenerateServiceName() = %v, want %v", got, tt.want)
			}
		})
	}
}

// TestParseServiceName tests the ParseServiceName function for various URIs
func TestParseServiceName(t *testing.T) {
	tests := []struct {
		name    string
		uri     string
		want    *ServiceInfo
		wantErr bool
	}{
		{
			name: "with type and ip and metadata",
			uri:  "tcp://svc.ns.cluster:7000/pod/10.0.0.1?a=1&b=2",
			want: &ServiceInfo{
				Protocol: "tcp", Name: "svc", Namespace: "ns",
				Cluster: "cluster", Port: 7000, Type: "pod", IP: "10.0.0.1",
				Metadata: map[string]string{"a": "1", "b": "2"},
			},
		},
		{
			name: "with type and ip and metadata",
			uri:  "udp://svc.ns.cluster:7000/pod/10.0.0.1?a=1&b=2",
			want: &ServiceInfo{
				Protocol: "udp", Name: "svc", Namespace: "ns",
				Cluster: "cluster", Port: 7000, Type: "pod", IP: "10.0.0.1",
				Metadata: map[string]string{"a": "1", "b": "2"},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParseServiceName(tt.uri)
			if (err != nil) != tt.wantErr {
				t.Errorf("ParseServiceName() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if err == nil {
				if !reflect.DeepEqual(got, tt.want) {
					t.Errorf("ParseServiceName() = %#v, want %#v", got, tt.want)
				}
			}
		})
	}
}
