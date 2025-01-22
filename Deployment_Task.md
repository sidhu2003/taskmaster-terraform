
# Deployment of Application in AWS

This document comprehensively describes an AWS architecture designed for a cloud-native application. The architecture integrates various AWS services to ensure secure, scalable, and cost-effective deployment.

![enter image description here](https://64.media.tumblr.com/09f4e356afdcd773b792b09c2f29c4b9/42583509427ace51-5a/s2048x3072/321bb0bbc5d4862ed34506109316afbafa4179f5.pnj)

This is the abstract architecture I have come up with in the case study.
## Architecture Components

1.  **Frontend Hosting**
    
    -   **Amazon S3**: The frontend application is hosted as a static website on S3, allowing for easy content storage and retrieval.
    -   **Amazon CloudFront**: Acts as a Content Delivery Network (CDN), caching content at edge locations to improve performance and reduce latency.
    
2.  **Backend Hosting**
    
    -   **Amazon ECS**: The backend application runs on Amazon Elastic Container Service (ECS) using either Fargate within private subnets, ensuring that backend services are not publicly accessible.
    -   **API Gateway**: As the interface between the front end and back end, routing API requests to ECS tasks via an Application Load Balancer (ALB).
    
3.  **Database**
    -   **Amazon RDS**: A PostgreSQL RDS instance is deployed in private subnets, ensuring data security and isolation from the public internet. **IAM Database Authentication** is enabled for secure connections from ECS tasks.

4.  **Environment Variables Management**
    
    -   Sensitive data such as API keys are stored securely in the AWS Systems Manager Parameter Store. ECS tasks have specific IAM permissions to retrieve these values at runtime.
    
5.  **Networking and Security**
    -   A Virtual Private Cloud (VPC) is established with both public and private subnets:
        
        -   Public subnets host CloudFront and the ALB.
        -   Private subnets host ECS tasks and the RDS instance.

## Overview

-   **Frontend Access**: Users access the frontend via CloudFront, which fetches content from the S3 bucket.
-   **API Requests**: The frontend sends requests to the API Gateway, which routes them to the ALB or directly to ECS tasks in private subnets.
-   **Database Interaction**: ECS tasks communicate securely with the RDS instance using IAM authentication.
-   **AWS Service Access**: ECS tasks utilize VPC Endpoints for accessing AWS services like S3 and Systems Manager Parameter Store.


# Best Practices followed

1.  **Scalability Design**
    
    -   The architecture is designed to scale automatically using **Amazon ECS** with Fargate.
    
2.  **Cost Optimization**
    
    -   By utilizing **VPC Endpoints**, the architecture minimizes costs associated with outbound internet traffic.
    
3.  **Security Measures**
    
    -   Implemented **IAM Best Practices** by enforcing the principle of least privilege, ensuring that ECS tasks have only the permissions necessary to function.
  
    
4.  **High Availability**
    -   The use of multiple Availability Zones (AZs) for deploying the RDS instance enhances redundancy and failover capabilities, minimizing downtime during maintenance or outages.


# Furthur Improvements

-   Implementing more advanced security measures such as **AWS WAF (Web Application Firewall)** to protect against common web exploits and improve application security posture.
-  Explore further adoption of serverless technologies like AWS Lambda for specific workloads that can benefit from event-driven computing.

# References 


https://cloudar.be/awsblog/connect-to-private-resources-from-api-gateway-with-vpc-link/

https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.Connecting.html

https://aws.amazon.com/blogs/networking-and-content-delivery/amazon-s3-amazon-cloudfront-a-match-made-in-the-cloud/
