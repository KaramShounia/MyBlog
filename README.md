# MyBlog Project 

I wanted to create this blog project to showcase my knowledge and expertise in creating and managing infrastructure on AWS using Terraform. I wanted to show my knowledge in AWS services as well as IaC. 

### Setting up VPC, Subnets, Internet Gateway, and Route Tables

The first step of the project was setting up my VPC and the required subnets. I created two public subnets and two private subnets for high availability. Also, I wanted to have my instances and database in private subnet as a security best practice so that it cannot be accessed by the internet. I also setup an internet gateway for public access as well as set up route tables to route traffic from the private subnets all the way to the internet gateway. 

### Setting up NAT Instance and Security Groups 

The next step of the project was to setup a NAT instance for internet access. I chose to go with a NAT instance as a cost optimization option over having a NAT Gateway. There was a module ready for use for setting up a NAT instance. Next, I set up all the security groups that will be needed for my instances, RDS, and ALB with the correct ports and protocols.   

### Setting up S3 and RDS

The next part of the project was setting up an S3 bucket that can be used to store up my blog assets. For now, it is being used to store up my static webpage that will be served on my EC2 instances. I setup the correct bucket policies, IAM role, and instance profile so that the EC2 instances can access the information in my S3 bucket. I also setup my RDS database that will serve content to my instances in the future. For now, it shows the RDS endpoint and database version as a proof of connectivity between EC2 instances and RDS database.

### Setting up EC2, Launch Templates, Auto Scaling Groups, and Application Load Balancer 

Next, I setup the user_data script that will be loaded into the EC2 instance once they are configured and launched. I set up the launch template with the necessary configurations for my EC2 instances. I then configured the auto scaling group for my desired capacity and to use the launch template I set up before. Finally, I set up the application load balancer along with the target group and listener rules. This enabled my static webpage to be accessible from the ALB. 

### Future Improvements on Architecture 

I plan on making improvements to my infrastructure over time. My next steps would be to make a live blog so that I can continuously make new posts on the website. Also, I want to improve the integration with RDS. Another improvement I would like to make is adding a sign-in page using Amazon Cognito. 