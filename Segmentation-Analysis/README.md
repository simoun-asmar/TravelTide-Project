# Segmentation Analysis

This folder contains the analysis performed to create the segmentation of Travel Tide users using K-Means Clustering. Below is an explanation of the process, features used, and the resulting groups.

## Features Used for Clustering
To segment the users effectively, I selected the following features:

1. **Conversion Rate**: Indicates the likelihood of a user booking after browsing. This is important for identifying engagement and intent.
2. **Total Clicks**: Reflects user activity and browsing behavior during sessions.
3. **Average Session Duration**: Shows how much time users spend exploring options, indicating their interest and engagement.
4. **Discount Usage (Flights and Hotels)**: Highlights price sensitivity and reliance on discounts.
5. **Money Spent Booking**: Identifies the spending capacity and premium preferences of users.
6. **Total Flights and Hotels Booked**: Represents user activity levels in terms of actual bookings.
7. **Miles Flown**: Indicates travel preferences and the frequency of long-distance travel.

[View Inputs for Clustering](Inputs-For-Clustering.png)

## Clustering Process
Using the features mentioned above, I applied **K-Means Clustering** in Tableau. The process resulted in:

- **Number of Clusters**: 4 primary clusters were identified. However, there was also a **Not Clustered** group.  
  - **Investigation of Not Clustered Group**: Users in this group had null values for key metrics, likely because they engaged with discounts and other features but never completed a booking. This lack of complete data prevented them from being assigned to a cluster.  


## Groups Created
The clustering process resulted in five distinct user groups based on their behavior and spending patterns:

1. **Budget Optimizers**: The largest group focused on discounts and minimal spending.
2. **Premium Maximizers**: Users who prioritize premium options and spend significantly more.
3. **Strategic Savers**: A small group, highly focused on maximizing discounts.
4. **Value Hunters**: Users balancing moderate spending with a focus on extracting value.
5. **Browsing Hesitants** (Not Clustered): Users who engaged with the platform, used discounts, but never completed a booking.

[View Groups](Groups.png)

## Visual Representation of Clusters
The scatter plot below shows the clusters using **Total Clicks** and **Conversion Rate** for visualization purposes. However, it is important to note that the clustering itself was based on all the features mentioned earlier, not just these two variables.

[View Clusters](Clusters.png)

By combining the feature analysis and clustering results, I identified meaningful user segments to tailor recommendations and offers, enhancing user engagement and satisfaction.

---

### Click on the icon below to see the next step:

[![Next Step - ERD](https://img.icons8.com/fluency/48/arrow.png)](../)
