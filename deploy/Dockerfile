FROM ghost:5-alpine

# Set Ghost to run in production mode
ENV NODE_ENV production

# Copy custom themes if they exist
COPY content/themes /var/lib/ghost/content/themes

# Set proper permissions
RUN chown -R node:node /var/lib/ghost/content/themes

# Use node user from base image
USER node

# Expose Ghost port
EXPOSE 2368

# Start Ghost
CMD ["node", "current/index.js"] 