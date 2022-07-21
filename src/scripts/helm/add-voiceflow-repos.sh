#!/bin/bash

helm repo add voiceflow-charts-s3 s3://voiceflow-charts
helm repo add voiceflow-charts-s3-private s3://voiceflow-charts-private
helm repo add voiceflow-charts-s3-beta s3://voiceflow-charts-beta
helm repo update