export abstract class BaseEntity {
  id: string;
  createdAt: Date;
  updatedAt: Date;

  constructor(id: string, createdAt: Date, updatedAt: Date) {
    this.id = id;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  /**
   * Check if entity was created recently (within last hour)
   */
  isRecent(): boolean {
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
    return this.createdAt > oneHourAgo;
  }

  /**
   * Check if entity has been modified since creation
   */
  isModified(): boolean {
    return this.updatedAt.getTime() !== this.createdAt.getTime();
  }
}
