#!/usr/bin/env bash
# lifemaestro/core/interfaces.sh - Module interface definitions
#
# This file defines the expected interface for each adapter type.
# Adapters should implement these functions.

# ============================================
# AI INTERFACE
# ============================================

# ai::available() -> bool
# Check if this AI adapter is available

# ai::chat "$message" -> string
# Send a message and get response

# ai::ask "$question" -> string
# Ask a one-shot question

# ai::stream "$message" -> stream
# Stream response to stdout

# ============================================
# MAIL INTERFACE
# ============================================

# mail::list "$folder" -> json
# List messages in folder

# mail::read "$id" -> json
# Read a specific message

# mail::send "$to" "$subject" "$body" -> bool
# Send an email

# mail::search "$query" -> json
# Search messages

# ============================================
# SECRETS INTERFACE
# ============================================

# secrets::get "$key" -> string
# Get a secret value

# secrets::set "$key" "$value" -> bool
# Set a secret value

# secrets::exists "$key" -> bool
# Check if secret exists

# ============================================
# SEARCH INTERFACE
# ============================================

# search::query "$terms" -> json
# Search across indexed content

# search::index "$path" -> bool
# Index content at path

# ============================================
# CALENDAR INTERFACE
# ============================================

# calendar::today -> json
# Get today's events

# calendar::week -> json
# Get this week's events

# calendar::add "$title" "$date" "$time" -> bool
# Add a new event
