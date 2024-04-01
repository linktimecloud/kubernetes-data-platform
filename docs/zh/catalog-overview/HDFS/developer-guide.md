# HDFS 开发指南

下面将介绍如何通过 Java API 接口方式进行 HDFS 的相关操作。

## HDFS 初始化

在使用 HDFS 提供的 API 之前，需要先进行 HDFS 初始化操作。初始化 HDFS 时会加载 HDFS 的配置文件，HDFS 使用到的配置文件主要为 core-site.xml 和 hdfs-site.xml 两个文件，可以从 configmap `hdfs-config` 中得到。

初始化代码样例如下。

```java
 private void init() throws IOException {
   conf = new Configuration();
   // conf path for core-site.xml and hdfs-site.xml
   conf.addResource(new Path(PATH_TO_HDFS_SITE_XML));
   conf.addResource(new Path(PATH_TO_CORE_SITE_XML));
   fSystem = FileSystem.get(conf);
 }
```

在 HDFS 文件系统初始化之后，就可以调用 HDFS 提供的各种 API 进行开发。

## 创建目录

如果要在 HDFS 文件系统中创建目录，需要 FileSystem 实例的 exists 方法判断该目录是否已经存在：

- 如果存在，则直接返回。
- 如果不存在，则调用 FileSystem 实例的 mkdirs 方法创建该目录。

创建目录代码样例如下。

```java
/**
 * create directory path
 *
 * @param dirPath
 * @return
 * @throws java.io.IOException
 */
private boolean createPath(final Path dirPath) throws IOException {
    if (!fSystem.exists(dirPath)) {
        fSystem.mkdirs(dirPath);
    }
    return true;
}
```

## 写文件

通过调用 FileSystem 实例的 create 方法获取写文件的输出流。通常获得输出流之后，可以直接对这个输出流进行写入操作，将内容写入 HDFS 的指定文件中。写完文件后，需要调用 close 方法关闭输出流。

写文件代码样例如下。

```java
/**
 * 创建文件，写文件
 *
 * @throws java.io.IOException
 */
private void createAndWrite() throws IOException {
   final String content = "Hello HDFS!";
   FSDataOutputStream out = null;
   try {
       out = fSystem.create(new Path(DEST_PATH + File.separator + FILE_NAME));
       out.write(content.getBytes());
       out.hsync();
       LOG.info("success to write.");
   } finally {
    // make sure the stream is closed finally.
       out.close();
  }
}
```

## 追加文件内容

对于已经在 HDFS 中存在的文件，可以追加指定的内容，以增量的形式在该文件现有内容的后面追加。通过调用 FileSystem 实例的 append 方法获取追加写入的输出流。然后使用该输出流将待追加内容添加到 HDFS 的指定文件后面。追加完指定的内容后，需要调用 close 方法关闭输出流。

> **注意**：需要确保待追加的文件已经存在，并且没有正在被写入内容，否则追加内容会失败抛出异常。

追加文件内容代码样例如下。

```java
/**
 * 追加文件内容
 *
 * @throws java.io.IOException
 */
private void appendContents() throws IOException {
    final String content = "Hello Hello";
    FSDataOutputStream out = null;
    try {
        out = fSystem.append(new Path(DEST_PATH + File.separator + FILE_NAME));
        out.write(content.getBytes());
        out.hsync();
        LOG.info("success to append.");
    } finally {
        // make sure the stream is closed finally.
        out.close();
    }
}
```

## 读文件

读文件即为获取 HDFS 上某个指定文件的内容。通过调用 FileSystem 实例的 open 方法获取读取文件的输入流。然后使用该输入流读取 HDFS 的指定文件的内容。读完文件后，需要调用 close 方法关闭输入流。

读文件代码样例如下。

```java
private void read() throws IOException {
    String strPath = DEST_PATH + File.separator + FILE_NAME;
    Path path = new Path(strPath);
    FSDataInputStream in = null;
    BufferedReader reader = null;
    StringBuffer strBuffer = new StringBuffer();
    try {
        in = fSystem.open(path);
        reader = new BufferedReader(new InputStreamReader(in));
        String sTempOneLine;
        // write file
        while ((sTempOneLine = reader.readLine()) != null) {
            strBuffer.append(sTempOneLine);
        }
        LOG.info("result is : " + strBuffer.toString());
        LOG.info("success to read.");
    } finally {
        // make sure the streams are closed finally.
        IOUtils.closeStream(reader);
        IOUtils.closeStream(in);
    }
}
```

## 删除目录

通过调用 delete 方法删除 HDFS 上某个指定目录。delete 方法第二个参数代表是否递归删除目录下面的所有目录。如果该参数为 false，而目录下还存在文件或者子目录，则删除目录操作会失败。

> **注意**：待删除的目录会被直接删除，且无法恢复，因此，请谨慎使用删除目录操作。

删除目录代码样例如下。

```java
private boolean deletePath(final Path dirPath) throws IOException {
    if (!fSystem.exists(dirPath)) {
        return false;
    }
    // fSystem.delete(dirPath, true);
    return fSystem.delete(dirPath, true);
}
```

## 删除文件

通过调用 delete 方法删除 HDFS 上某个指定文件。

> **注意**：待删除的文件会被直接删除，且无法恢复，因此，请谨慎使用删除文件操作。

删除文件代码样例如下。

```java
private void deleteFile() throws IOException {
    Path beDeletedPath = new Path(DEST_PATH + File.separator + FILE_NAME);
    if (fSystem.delete(beDeletedPath, true)) {
        LOG.info("success to delete the file " + DEST_PATH + File.separator + FILE_NAME);
    } else {
        LOG.warn("failed to delete the file " + DEST_PATH + File.separator + FILE_NAME);
    }
}
```

## 移动或重命名文件

对于 HDFS 来说，文件的重命名和移动是一个操作。调用 FileSystem 的 rename 方法对 HDFS 文件系统的文件进行重命名操作。

> **注意**：rename 方法的原文件必须存在，并且目标文件不能存在，否则重命名操作会失败。

移动或重命名文件代码样例如下。

```java
private void renameFile() throws IOException {
    Path srcFilePath = new Path(SRC_PATH + File.separator + SRC_FILE_NAME);
    Path destFilePath = new Path(DEST_PATH + File.separator + DEST_FILE_NAME);
        fs.rename(new Path(srcFilePath), new Path(destFilePath));
}
```

## 移动或重命名目录

对于 HDFS 来说，目录的重命名和移动是一个操作。调用 FileSystem 的 rename 方法对 HDFS 文件系统的目录进行重命名操作。

> **注意**：rename 方法的原目录必须存在，并且目标目录不能存在，否则重命名操作会失败。

移动或重命名目录代码样例如下。

```java
private void renameDir() throws IOException {
    Path srcDirPath = new Path(SRC_PATH + File.separator + SRC_DIR_NAME);
    Path destDirPath = new Path(DEST_PATH + File.separator + DEST_DIR_NAME);
        fs.rename(new Path(srcDirPath), new Path(destDirPath));
}
```
