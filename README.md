# Measuring the Benefits of Distroless Containers

<!-- markdown-link-check-disable-next-line -->

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![GitHub Super-Linter](https://github.com/electrocucaracha/k8s-Distroless-demo/workflows/Lint%20Code%20Base/badge.svg)](https://github.com/marketplace/actions/super-linter)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)

<!-- markdown-link-check-disable-next-line -->

![visitors](https://visitor-badge.laobi.icu/badge?page_id=electrocucaracha.k8s-Distroless-demo)
[![Scc Code Badge](https://sloc.xyz/github/electrocucaracha/k8s-Distroless-demo?category=code)](https://github.com/boyter/scc/)
[![Scc COCOMO Badge](https://sloc.xyz/github/electrocucaracha/k8s-Distroless-demo?category=cocomo)](https://github.com/boyter/scc/)

## Summary

This demo project highlights the advantages of using Distroless containers by evaluating key metrics such as image size, deployment time, and data transfer efficiency.

### Objectives

- **Image Size Reduction**: Compare the size of a standard container image with a Distroless version.
- **Deployment Time Improvement**: Measure the deployment time reduction achieved by using Distroless containers.
- **Data Transfer Efficiency**: Analyze the impact on network usage and costs when deploying to cloud environments.

### Methodology

1. **Initial Setup**: Provision a Kubernetes cluster connected to a private Docker registry and create a standard container image, including build tools and a generic JRE.
1. **Implementation of Best Practices**: Utilize [Multi-stage builds][1] and [Distroless][2] best practices, along with tools like [jdeps][3] and [jlink][4] fro JRE optimization.
1. **Measurement**: Record metrics for image size, deployment time, and network usage during deployment to Kubernetes worker nodes.

### Outcomes

- Successfully reduced image size from 863MB to just 22.3MB.
- Lowered deployment time significantly, from 67.506 seconds to 14.515 seconds.
- Achieved ~58x reduction in data transfer from the private local registry to the seven Kubernetes worker nodes.

Using Distroless images can lead to monthly cost savings and minimize traffic congestion.

[1]: https://docs.docker.com/build/building/multi-stage/
[2]: https://github.com/GoogleContainerTools/distroless
[3]: https://dev.java/learn/jvm/tools/core/jdeps/
[4]: https://dev.java/learn/jvm/tools/core/jlink/
